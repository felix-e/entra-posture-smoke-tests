# Offline, synthetic-snapshot evaluator. Input: ConvertFrom-Json -AsHashtable output.
# Required root arrays: applications, servicePrincipals, conditionalAccessPolicies.
# Required config: riskyRoleIds (array), allowedExcludedUserIds (array),
# exceptionGroupNamePattern (regex), exceptionGroups (array of {id,owner,lastReviewedAt,expiresAt}).
# applications: {id,signInAudience,requestedRoles:[role strings],approvedRiskyRoleIds:[role strings],
# businessOwner,lastReviewedAt,credentials:[{type,startDateTime,endDateTime}]}.
# signInAudience is 'multiTenant' or 'singleTenant'; credential type is 'secret',
# 'certificate', or 'federation' (federation has no expiry date).
# servicePrincipals: {appId,servicePrincipalType,accountEnabled,decommissionedAt}.
# conditionalAccessPolicies: {excludedUserIds:[strings],excludedGroups:[{id,displayName}]}.
# Missing required fields on applicable objects are counted as failures. Dates are
# ISO 8601 with explicit UTC offset; UTC comparisons use the optional -Now clock.

function Field($item, [string]$key) {
    if ($item -is [System.Collections.IDictionary] -and $item.Contains($key)) { return ,$item[$key] }
    return $null
}
function Has($item, [string]$key) {
    return ($item -is [System.Collections.IDictionary] -and $item.Contains($key) -and $null -ne $item[$key])
}
function List($item, [string]$key) {
    if (-not (Has $item $key) -or (Field $item $key) -isnot [array]) { return $null }
    return ,(Field $item $key)
}
function Date($value) {
    if ($value -is [datetimeoffset]) { return $value }
    if ($value -is [datetime]) {
        if ($value.Kind -eq [DateTimeKind]::Unspecified) { return $null }
        return [datetimeoffset]$value
    }
    if ($value -isnot [string] -or $value -notmatch '^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?(?:Z|[+-]\d\d:\d\d)$') { return $null }
    $parsed = [datetimeoffset]::MinValue
    if ([datetimeoffset]::TryParse($value, [cultureinfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsed)) { return $parsed }
    return $null
}
function Empty($value) { return ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value)) }
function AddResult($id, $domain, $count) {
    [pscustomobject]@{ id = $id; domain = $domain; pass = ($count -eq 0); count = [int]$count }
}

function Test-PostureChecks {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Snapshot,
        [datetimeoffset]$Now = [datetimeoffset]::UtcNow
    )
    $nowUtc = $Now.ToUniversalTime()
    $config = Field $Snapshot 'config'
    $apps = List $Snapshot 'applications'
    $sps = List $Snapshot 'servicePrincipals'
    $policies = List $Snapshot 'conditionalAccessPolicies'
    $risky = List $config 'riskyRoleIds'
    $allowed = List $config 'allowedExcludedUserIds'
    $exceptions = List $config 'exceptionGroups'
    $pattern = Field $config 'exceptionGroupNamePattern'
    $patternValid = $pattern -is [string] -and -not [string]::IsNullOrWhiteSpace($pattern)
    if ($patternValid) { try { [void][regex]::new($pattern); } catch { $patternValid = $false } }
    $counts = @{}
    foreach ($id in @('LOCAL.PERM.001','LOCAL.PERM.002','LOCAL.PERM.003','LOCAL.OWNER.001','LOCAL.OWNER.002','LOCAL.OWNER.003','LOCAL.CRED.001','LOCAL.CRED.002','LOCAL.CRED.003','LOCAL.CRED.004','LOCAL.CA.001','LOCAL.CA.002','LOCAL.CA.003')) { $counts[$id] = 0 }
    $riskValid = $null -ne $risky -and $risky.Count -gt 0 -and @($risky | Where-Object { Empty $_ }).Count -eq 0
    if ($null -ne $apps -and $apps.Count -eq 0 -and -not $riskValid) {
        foreach ($id in @('LOCAL.PERM.001','LOCAL.PERM.002','LOCAL.OWNER.001','LOCAL.OWNER.002')) { $counts[$id]++ }
    }
    if ($null -eq $apps) { foreach ($id in @('LOCAL.PERM.001','LOCAL.PERM.002','LOCAL.PERM.003','LOCAL.OWNER.001','LOCAL.OWNER.002','LOCAL.CRED.001','LOCAL.CRED.002','LOCAL.CRED.003','LOCAL.CRED.004')) { $counts[$id]++ } }
    else {
        foreach ($app in $apps) {
            $roles = List $app 'requestedRoles'
            $approved = List $app 'approvedRiskyRoleIds'
            $credentials = List $app 'credentials'
            $invalidRoles = $null -eq $roles -or -not $riskValid -or @($roles | Where-Object { Empty $_ }).Count -gt 0
            $riskRoles = @()
            if (-not $invalidRoles) { $riskRoles = @($roles | Where-Object { $risky -ccontains $_ }) }
            $unapproved = $invalidRoles -or $null -eq $approved -or @($riskRoles | Where-Object { $approved -cnotcontains $_ }).Count -gt 0
            if ($unapproved) { $counts['LOCAL.PERM.001']++ }
            $audience = Field $app 'signInAudience'
            if ($invalidRoles -or (Empty $audience) -or ($audience -cnotin @('multiTenant','singleTenant')) -or ($audience -ceq 'multiTenant' -and $riskRoles.Count -gt 0)) { $counts['LOCAL.PERM.002']++ }
            $critical = @('RoleManagement.ReadWrite.Directory','Policy.ReadWrite.ConditionalAccess','AppRoleAssignment.ReadWrite.All')
            if ($null -eq $roles -or @($roles | Where-Object { $critical -ccontains $_ }).Count -gt 0) { $counts['LOCAL.PERM.003']++ }
            if ($invalidRoles -or ($riskRoles.Count -gt 0 -and (Empty (Field $app 'businessOwner')))) { $counts['LOCAL.OWNER.001']++ }
            $review = Date (Field $app 'lastReviewedAt')
            if ($invalidRoles -or ($riskRoles.Count -gt 0 -and ($null -eq $review -or $review -gt $nowUtc -or $review -lt $nowUtc.AddDays(-365)))) { $counts['LOCAL.OWNER.002']++ }
            if ($null -eq $credentials) { foreach ($id in @('LOCAL.CRED.001','LOCAL.CRED.002','LOCAL.CRED.003','LOCAL.CRED.004')) { $counts[$id]++ }; continue }
            $badEnd = $false; $expired = $false; $soon = $false; $long = $false; $secret = $false; $alternative = $false
            foreach ($credential in $credentials) {
                $type = Field $credential 'type'
                if ($type -ceq 'federation') { $alternative = $true; continue }
                $end = Date (Field $credential 'endDateTime')
                if ($type -cnotin @('secret','certificate') -or $null -eq $end) { $badEnd = $true; continue }
                if ($end -lt $nowUtc) { $expired = $true }
                elseif ($end -le $nowUtc.AddDays(30)) { $soon = $true }
                if ($type -ceq 'secret') {
                    $secret = $true
                    $start = Date (Field $credential 'startDateTime')
                    if ($null -eq $start -or $end -lt $start) { $long = $true }
                    elseif ($end -gt $start.AddYears(2)) { $long = $true }
                } else { $alternative = $true }
            }
            if ($badEnd -or $expired) { $counts['LOCAL.CRED.001']++ }
            if ($badEnd -or $soon) { $counts['LOCAL.CRED.002']++ }
            if ($badEnd -or $long) { $counts['LOCAL.CRED.003']++ }
            if ($badEnd -or ($secret -and -not $alternative)) { $counts['LOCAL.CRED.004']++ }
        }
    }
    if ($null -eq $sps) { $counts['LOCAL.OWNER.003']++ }
    else { foreach ($sp in $sps) {
        $kind = Field $sp 'servicePrincipalType'
        if ($kind -eq 'ManagedIdentity') { continue }
        $enabled = Field $sp 'accountEnabled'
        $decommissioned = Date (Field $sp 'decommissionedAt')
        if ($kind -cne 'Application' -or (Empty (Field $sp 'appId')) -or $enabled -isnot [bool] -or ($enabled -eq $false -and ($null -eq $decommissioned -or $decommissioned -gt $nowUtc))) { $counts['LOCAL.OWNER.003']++ }
    } }
    if ($null -eq $policies) { foreach ($id in @('LOCAL.CA.001','LOCAL.CA.002','LOCAL.CA.003')) { $counts[$id]++ } }
    else { foreach ($policy in $policies) {
        $users = List $policy 'excludedUserIds'
        $groups = List $policy 'excludedGroups'
        if ($null -eq $users -or $null -eq $allowed) { $counts['LOCAL.CA.001']++ }
        else { foreach ($userId in $users) { if ((Empty $userId) -or $allowed -cnotcontains $userId) { $counts['LOCAL.CA.001']++ } } }
        if ($null -eq $groups -or -not $patternValid) { $counts['LOCAL.CA.002']++ }
        else { foreach ($group in $groups) { if ((Empty (Field $group 'id')) -or (Empty (Field $group 'displayName')) -or (Field $group 'displayName') -cnotmatch $pattern) { $counts['LOCAL.CA.002']++ } } }
        if ($null -eq $groups -or $null -eq $exceptions) { $counts['LOCAL.CA.003']++ }
        else { foreach ($group in $groups) {
            $metadata = @($exceptions | Where-Object { (Field $_ 'id') -ceq (Field $group 'id') -and -not (Empty (Field $_ 'id')) })
            $review = if ($metadata.Count -eq 1) { Date (Field $metadata[0] 'lastReviewedAt') } else { $null }
            $expiry = if ($metadata.Count -eq 1) { Date (Field $metadata[0] 'expiresAt') } else { $null }
            if ($metadata.Count -ne 1 -or (Empty (Field $metadata[0] 'owner')) -or $null -eq $review -or $review -gt $nowUtc -or $review -lt $nowUtc.AddDays(-365) -or $null -eq $expiry -or $expiry -le $nowUtc) { $counts['LOCAL.CA.003']++ }
        } }
    } }
    foreach ($item in @(
        @('LOCAL.PERM.001','app-lifecycle'),@('LOCAL.PERM.002','app-lifecycle'),@('LOCAL.PERM.003','app-lifecycle'),
        @('LOCAL.OWNER.001','app-lifecycle'),@('LOCAL.OWNER.002','app-lifecycle'),@('LOCAL.OWNER.003','app-lifecycle'),
        @('LOCAL.CRED.001','auth-credentials'),@('LOCAL.CRED.002','auth-credentials'),@('LOCAL.CRED.003','auth-credentials'),@('LOCAL.CRED.004','auth-credentials'),
        @('LOCAL.CA.001','ca-coverage-exclusions'),@('LOCAL.CA.002','ca-coverage-exclusions'),@('LOCAL.CA.003','ca-coverage-exclusions')
    )) { AddResult $item[0] $item[1] $counts[$item[0]] }
}
Export-ModuleMember -Function Test-PostureChecks
