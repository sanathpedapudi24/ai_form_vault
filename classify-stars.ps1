#!/usr/bin/env pwsh
# Classify GitHub starred repos into categories using gh CLI
# Usage: .\classify-stars.ps1

$ErrorActionPreference = "Stop"

Write-Host "Fetching your starred repos..." -ForegroundColor Cyan

# Get all starred repos as JSON array
$json = gh api /user/starred --jq '[.[] | {full_name, description, language, topics: (.topics // [])}]' 2>&1
$stars = $json | ConvertFrom-Json

# Classification rules based on topics, description, and language
$categories = @{
    "AI Engineering / Agents / RAG" = @(
        "ai-engineering","ai-agents","agent-orchestration","graphrag","knowledge-graph",
        "rag","llm","large-language-models","claude","claude-code","notebooklm","prompt-engineering",
        "generative-ai","multi-agent","mcp","fine-tuning","llm-inference","agents"
    )
    "Interview / CS / Study Plans" = @(
        "interview","interview-preparation","interview-questions","coding-interview",
        "coding-interviews","data-structures","algorithms","system-design","computer-science",
        "study-plan","programming-interviews","software-engineering","awesome-list","courses",
        "curriculum","project-ideas","placements","portfolio","resume","side-projects"
    )
    "Tools / Utils / Misc" = @(
        "awesome","cheatsheets","devops","security","linux","windows","macos",
        "productivity","utility","cli","web","dns","domain","svg","css","html"
    )
}

# Function to classify a repo
function Classify-Repo($repo) {
    $desc = if ($repo.description) { $repo.description } else { "" }
    $topics = if ($repo.topics) { $repo.topics } else { @() }
    $text = ($desc + " " + ($topics -join " ")).ToLower()
    $lang = if ($repo.language) { $repo.language.ToLower() } else { "" }

    foreach ($cat in $categories.Keys) {
        foreach ($keyword in $categories[$cat]) {
            if ($text.Contains($keyword.ToLower()) -or $lang -eq $keyword.ToLower()) {
                return $cat
            }
        }
    }
    return "Tools / Utils / Misc"
}

# Classify each repo
$classified = @()
foreach ($repo in $stars) {
    $category = Classify-Repo $repo
    $classified += [PSCustomObject]@{
        FullName = $repo.full_name
        Category = $category
        Language = if ($repo.language) { $repo.language } else { "" }
        Description = if ($repo.description) { $repo.description } else { "" }
        Topics = if ($repo.topics) { ($repo.topics -join ", ") } else { "" }
    }
}

# Group by category and display
Write-Host "`n=== YOUR STARS BY CATEGORY ===" -ForegroundColor Green
$classified | Group-Object Category | ForEach-Object {
    Write-Host "`n## $($_.Name) ($($_.Count) repos)" -ForegroundColor Yellow
    $_.Group | ForEach-Object {
        Write-Host "  - $($_.FullName) [$($_.Language)] $($_.Description)"
    }
}

# Export to CSV
$classified | Export-Csv -Path "stars-classified.csv" -NoTypeInformation -Encoding utf8
Write-Host "`nExported to stars-classified.csv" -ForegroundColor Cyan

# Manual steps for GitHub web UI
Write-Host "`n=== MANUAL STEPS ON GITHUB.COM ===" -ForegroundColor Cyan
Write-Host "1. Go to https://github.com/charansaiponnada?tab=stars"
Write-Host "2. Click 'New list' to create each category above"
Write-Host "3. Add repos to each list manually (API for starred lists not yet public)"
