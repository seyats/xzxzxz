param(
    [int]$PostCount = 0,
    [string]$OutputPath = "$PSScriptRoot/../Tide/Resources/SeedContent.json"
)

$ErrorActionPreference = "Stop"
$names = @("Maya Chen", "Alex Rivera", "Noah Kim", "Sofia Petrova", "Leo Martin", "Ava Brooks", "Tide Support", "Durov")
$handles = @("maya", "alexr", "noah", "sofia", "leom", "avab", "TideSupport", "durov")
$bodies = @(
    "The best interfaces disappear into the rhythm of the day.",
    "A quiet morning by the water. Shot entirely on iPhone.",
    "Shipping a new way to connect: private when it matters, open when it helps.",
    "What are you building this week? Share a screenshot below.",
    "Music is architecture made of time. New session tonight on Tide Live.",
    "Small details are not small when millions of people touch them every day.",
    "Good software should feel less like a machine and more like a place.",
    "The next Tide build is focused on speed, accessibility and quieter notifications."
)
$posts = for ($index = 0; $index -lt $PostCount; $index++) {
    $authorIndex = $index % $names.Count
    [ordered]@{
        id = [guid]::NewGuid().ToString()
        author = [ordered]@{
            name = $names[$authorIndex]
            username = $handles[$authorIndex]
            verified = ($authorIndex -eq 0 -or $authorIndex -eq 2 -or $authorIndex -ge 6)
        }
        body = $bodies[$index % $bodies.Count]
        createdAt = [datetime]::UtcNow.AddMinutes(-15 * $index).ToString("o")
        statistics = [ordered]@{
            likes = 24 + ($index * 19)
            reposts = 3 + ($index * 4)
            comments = 2 + ($index * 3)
            views = 400 + ($index * 217)
        }
        tags = @("Tide", "iOS26", $(if ($index % 2 -eq 0) { "SwiftUI" } else { "Community" }))
        visibility = "everyone"
    }
}
$payload = [ordered]@{
    schemaVersion = 1
    generatedAt = [datetime]::UtcNow.ToString("o")
    posts = $posts
}
$directory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $directory -Force | Out-Null
$payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Output $OutputPath
