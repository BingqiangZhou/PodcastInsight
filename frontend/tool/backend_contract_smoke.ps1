param(
    [string]$BaseUrl = "http://localhost:8000"
)

$ErrorActionPreference = "Stop"

function Invoke-JsonRequest {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$Method,
        [hashtable]$Headers,
        [object]$Body
    )

    $requestParams = @{
        Uri         = $Uri
        Method      = $Method
        ContentType = "application/json"
    }

    if ($Headers) {
        $requestParams.Headers = $Headers
    }

    if ($null -ne $Body) {
        $requestParams.Body = ($Body | ConvertTo-Json -Depth 6)
    }

    Invoke-RestMethod @requestParams
}

$normalizedBaseUrl = $BaseUrl.TrimEnd("/")
$suffix = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$email = "smoke$suffix@example.com"
$username = "smoke$suffix"
$password = "Password123"

Write-Host "Checking health endpoints..."
$health = Invoke-JsonRequest -Uri "$normalizedBaseUrl/api/v1/health" -Method "Get"
$ready = Invoke-JsonRequest -Uri "$normalizedBaseUrl/api/v1/health/ready" -Method "Get"

Write-Host "Registering smoke user..."
$register = Invoke-JsonRequest `
    -Uri "$normalizedBaseUrl/api/v1/auth/register" `
    -Method "Post" `
    -Body @{
        email = $email
        password = $password
        username = $username
    }

Write-Host "Logging in smoke user..."
$login = Invoke-JsonRequest `
    -Uri "$normalizedBaseUrl/api/v1/auth/login" `
    -Method "Post" `
    -Body @{
        email_or_username = $email
        password = $password
        remember_me = $false
    }

Write-Host "Refreshing token..."
$refresh = Invoke-JsonRequest `
    -Uri "$normalizedBaseUrl/api/v1/auth/refresh" `
    -Method "Post" `
    -Body @{
        refresh_token = $register.refresh_token
    }

$headers = @{
    Authorization = "Bearer $($register.access_token)"
}

Write-Host "Checking protected podcast endpoints..."
$subscriptions = Invoke-JsonRequest `
    -Uri "$normalizedBaseUrl/api/v1/podcasts/subscriptions?page=1&size=20" `
    -Method "Get" `
    -Headers $headers
$feed = Invoke-JsonRequest `
    -Uri "$normalizedBaseUrl/api/v1/podcasts/episodes/feed?page=1&page_size=20" `
    -Method "Get" `
    -Headers $headers

@{
    health_status        = $health.status
    ready_status         = $ready.status
    register_has_token   = [bool]$register.access_token
    login_has_token      = [bool]$login.access_token
    refresh_has_token    = [bool]$refresh.access_token
    subscriptions_total  = $subscriptions.total
    subscriptions_page   = $subscriptions.page
    feed_total           = $feed.total
    feed_has_more        = $feed.has_more
} | ConvertTo-Json -Compress
