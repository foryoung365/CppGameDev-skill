Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$script:Results = @()

function Assert-Condition {
	param(
		[bool]$Condition,
		[string]$Message
	)

	if (-not $Condition) {
		throw $Message
	}
}

function Invoke-ToolkitCheck {
	param(
		[string]$Name,
		[scriptblock]$Action
	)

	try {
		& $Action
		$script:Results += [pscustomobject]@{
			Name = $Name
			Status = 'PASS'
			Details = ''
		}
	} catch {
		$script:Results += [pscustomobject]@{
			Name = $Name
			Status = 'FAIL'
			Details = $_.Exception.Message
		}
	}
}

function Get-FileText {
	param(
		[string]$Path
	)

	return [System.IO.File]::ReadAllText($Path)
}

function Get-SkillFiles {
	$skillRoot = Join-Path $repoRoot 'skills'
	Assert-Condition (Test-Path -LiteralPath $skillRoot) "Missing skills directory: $skillRoot"
	return @(Get-ChildItem -LiteralPath $skillRoot -Recurse -File -Filter 'SKILL.md' | Sort-Object FullName)
}

function Get-RuntimeTextFiles {
	$files = @()

	$files += @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'skills') -Recurse -File -Filter 'SKILL.md')
	$files += @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'agents') -File -Filter '*.md')
	$files += @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'commands') -File -Filter '*.md')
	$files += @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'docs\operator') -Recurse -File -Filter '*.md')

	$topLevelFiles = @(
		'README.md',
		'docs/upstream-mapping.md',
		'docs/workflow/request-lifecycle.md',
		'docs/svn/commit-policy.md',
		'docs/gameplay/context-card.md'
	)

	foreach ($relativePath in $topLevelFiles) {
		$fullPath = Join-Path $repoRoot $relativePath
		if (Test-Path -LiteralPath $fullPath) {
			$files += Get-Item -LiteralPath $fullPath
		}
	}

	return @($files | Sort-Object FullName -Unique)
}

function Test-SkillFrontMatter {
	param(
		[string]$Path
	)

	$lines = @(Get-Content -LiteralPath $Path -TotalCount 20)
	Assert-Condition ($lines.Count -ge 3) "${Path}: frontmatter is missing or too short"
	Assert-Condition ($lines[0] -eq '---') "${Path}: frontmatter must start with ---"

	$closingIndex = [Array]::IndexOf($lines, '---', 1)
	Assert-Condition ($closingIndex -gt 0) "${Path}: frontmatter must end with ---"

	$frontMatter = $lines[1..($closingIndex - 1)] -join "`n"
	Assert-Condition ($frontMatter -match '(?m)^name:\s*\S+') "${Path}: frontmatter is missing name"
	Assert-Condition ($frontMatter -match '(?m)^description:\s*\S+') "${Path}: frontmatter is missing description"
}

Invoke-ToolkitCheck 'plugin structure and manifest are valid' {
	$requiredPaths = @(
		'.claude-plugin\plugin.json',
		'.claude-plugin\marketplace.json',
		'settings.json',
		'skills',
		'agents',
		'commands',
		'docs\operator\quickstart.md'
	)

	$missing = @()
	foreach ($relativePath in $requiredPaths) {
		$fullPath = Join-Path $repoRoot $relativePath
		if (-not (Test-Path -LiteralPath $fullPath)) {
			$missing += $relativePath
		}
	}

	Assert-Condition ($missing.Count -eq 0) ('Missing required plugin paths: ' + ($missing -join ', '))

	$forbiddenPaths = @(
		'AGENTS.md',
		'CLAUDE.md',
		'rules'
	)

	$hits = @()
	foreach ($relativePath in $forbiddenPaths) {
		$fullPath = Join-Path $repoRoot $relativePath
		if (Test-Path -LiteralPath $fullPath) {
			$hits += $relativePath
		}
	}

	Assert-Condition ($hits.Count -eq 0) ('Retired paths must not exist: ' + ($hits -join ', '))

	$plugin = Get-Content -Raw -LiteralPath (Join-Path $repoRoot '.claude-plugin\plugin.json') | ConvertFrom-Json
	Assert-Condition ($plugin.name -eq 'cpp-mmorpg-gameplay') 'plugin.json name must be cpp-mmorpg-gameplay'
	Assert-Condition (-not [string]::IsNullOrWhiteSpace($plugin.description)) 'plugin.json description is required'
	Assert-Condition (-not [string]::IsNullOrWhiteSpace($plugin.version)) 'plugin.json version is required'
	Assert-Condition (-not [string]::IsNullOrWhiteSpace($plugin.homepage)) 'plugin.json homepage is required'
	Assert-Condition (-not [string]::IsNullOrWhiteSpace($plugin.repository)) 'plugin.json repository is required'

	$marketplace = Get-Content -Raw -LiteralPath (Join-Path $repoRoot '.claude-plugin\marketplace.json') | ConvertFrom-Json
	Assert-Condition ($marketplace.name -eq 'foryoung365-plugins') 'marketplace.json name must be foryoung365-plugins'
	Assert-Condition ($marketplace.plugins.Count -gt 0) 'marketplace.json must include at least one plugin entry'
	$pluginEntry = @($marketplace.plugins | Where-Object name -eq 'cpp-mmorpg-gameplay')
	Assert-Condition ($pluginEntry.Count -eq 1) 'marketplace.json must include exactly one cpp-mmorpg-gameplay entry'
	Assert-Condition ($pluginEntry[0].source -eq './') 'marketplace plugin entry must use relative source ./'

	$settings = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'settings.json') | ConvertFrom-Json
	Assert-Condition (-not [string]::IsNullOrWhiteSpace($settings.agent)) 'settings.json must define agent'
	$agentFile = Join-Path $repoRoot ("agents\{0}.md" -f $settings.agent)
	Assert-Condition (Test-Path -LiteralPath $agentFile) "settings.json agent target is missing: $agentFile"
}

Invoke-ToolkitCheck 'toolkit skill frontmatter' {
	$skillFiles = Get-SkillFiles
	Assert-Condition ($skillFiles.Count -gt 0) 'No toolkit skills were found under skills/'

	$missing = @()
	foreach ($skillFile in $skillFiles) {
		try {
			Test-SkillFrontMatter -Path $skillFile.FullName
		} catch {
			$missing += $_.Exception.Message
		}
	}

	Assert-Condition ($missing.Count -eq 0) ($missing -join '; ')
}

Invoke-ToolkitCheck 'runtime wording avoids stale git/worktree/PR flow terms' {
	$runtimeFiles = Get-RuntimeTextFiles
	$stalePatterns = @(
		'\bgit\b',
		'worktree',
		'pull request',
		'\bPR\b',
		'feature branch',
		'base branch',
		'development branch',
		'branch cleanup',
		'\bmerge\b',
		'\brebase\b',
		'\bcherry-pick\b'
	)

	$hits = @()
	foreach ($file in $runtimeFiles) {
		$text = Get-FileText -Path $file.FullName
		foreach ($pattern in $stalePatterns) {
			if ($text -match $pattern) {
				$hits += "$($file.FullName): matched $pattern"
			}
		}
	}

	Assert-Condition ($hits.Count -eq 0) ($hits -join '; ')
}

Invoke-ToolkitCheck 'toolkit remains self-contained without vendored upstream repos' {
	$unexpectedPaths = @(
		'.repo-context',
		'references',
		'references/superpowers',
		'references/ecc-cpp',
		'cpp-coding-standards-skill'
	)

	$hits = @()
	foreach ($relativePath in $unexpectedPaths) {
		$fullPath = Join-Path $repoRoot $relativePath
		if (Test-Path -LiteralPath $fullPath) {
			$hits += $relativePath
		}
	}

	Assert-Condition ($hits.Count -eq 0) ('Vendored upstream content should not exist inside the toolkit: ' + ($hits -join ', '))
}

Invoke-ToolkitCheck 'runtime intake chain stays intact in plugin authorities' {
	$chainPattern = 'request\s*->\s*gameplay-context-guard\s*->\s*task-intake-router\s*->\s*pre-plan'
	$keyFiles = @(
		'README.md',
		'agents/gameplay-main.md',
		'docs/workflow/request-lifecycle.md'
	)

	$missing = @()
	foreach ($relativePath in $keyFiles) {
		$fullPath = Join-Path $repoRoot $relativePath
		$text = Get-FileText -Path $fullPath
		if ($text -notmatch $chainPattern) {
			$missing += "$relativePath missing request -> gameplay-context-guard -> task-intake-router -> pre-plan"
		}
	}

	Assert-Condition ($missing.Count -eq 0) ($missing -join '; ')
}

Invoke-ToolkitCheck 'project-first governance stays explicit in runtime authorities' {
	$keyFiles = @(
		'README.md',
		'agents/gameplay-main.md',
		'skills/cpp-coding-standards/SKILL.md'
	)

	$missing = @()
	foreach ($relativePath in $keyFiles) {
		$text = Get-FileText -Path (Join-Path $repoRoot $relativePath)
		if ($text -notmatch 'Project conventions override imported ECC defaults|Project conventions override imported generic defaults|Project-local conventions are the default') {
			$missing += "$relativePath missing project-first governance wording"
		}
	}

	Assert-Condition ($missing.Count -eq 0) ($missing -join '; ')
}

Invoke-ToolkitCheck 'routing vocabulary uses approved plan names' {
	$routingFiles = @(
		'docs/workflow/request-lifecycle.md',
		'skills/task-intake-router/SKILL.md',
		'skills/lightweight-change-flow/SKILL.md',
		'skills/standard-feature-flow/SKILL.md',
		'skills/systematic-debugging/SKILL.md',
		'agents/gameplay-main.md'
	)

	$requirements = [ordered]@{
		'docs/workflow/request-lifecycle.md' = @('micro-plan', 'short-plan', 'full-plan', 'debugging-plan')
		'skills/task-intake-router/SKILL.md' = @('micro-plan', 'short-plan', 'full-plan', 'debugging-plan', 'pre-plan')
		'skills/lightweight-change-flow/SKILL.md' = @('micro-plan')
		'skills/standard-feature-flow/SKILL.md' = @('short-plan')
		'skills/systematic-debugging/SKILL.md' = @('debugging-plan')
		'agents/gameplay-main.md' = @('micro-plan', 'short-plan', 'full-plan', 'debugging-plan', 'pre-plan')
	}

	$missing = @()
	foreach ($relativePath in $routingFiles) {
		$fullPath = Join-Path $repoRoot $relativePath
		$text = Get-FileText -Path $fullPath
		foreach ($term in $requirements[$relativePath]) {
			if ($text -notmatch [regex]::Escape($term)) {
				$missing += "$relativePath missing $term"
			}
		}
	}

	Assert-Condition ($missing.Count -eq 0) ($missing -join '; ')
}

Invoke-ToolkitCheck 'svn delivery remains feature-sized in runtime files' {
	$files = @(
		'README.md',
		'agents/gameplay-main.md',
		'docs/svn/commit-policy.md',
		'skills/svn-delivery-handoff/SKILL.md',
		'skills/verification-before-completion/SKILL.md'
	)

	$requiredPatterns = @(
		'feature-sized',
		'one complete feature or one complete fix'
	)

	$missing = @()
	foreach ($relativePath in $files) {
		$text = Get-FileText -Path (Join-Path $repoRoot $relativePath)
		foreach ($pattern in $requiredPatterns) {
			if ($text -notmatch [regex]::Escape($pattern)) {
				$missing += "$relativePath missing $pattern"
			}
		}
	}

	Assert-Condition ($missing.Count -eq 0) ($missing -join '; ')
}

Invoke-ToolkitCheck 'commit gate semantic trio stays aligned across runtime files' {
	$gateFiles = @(
		'README.md',
		'agents/gameplay-main.md',
		'docs/svn/commit-policy.md',
		'skills/verification-before-completion/SKILL.md'
	)

	$requiredPhrases = @(
		'fresh successful compile',
		'commit-ready',
		'targeted validation'
	)

	$missing = @()
	foreach ($relativePath in $gateFiles) {
		$text = Get-FileText -Path (Join-Path $repoRoot $relativePath)
		foreach ($phrase in $requiredPhrases) {
			if ($text -notmatch [regex]::Escape($phrase)) {
				$missing += "$relativePath missing $phrase"
			}
		}
	}

	$handoffPath = Join-Path $repoRoot 'skills/svn-delivery-handoff/SKILL.md'
	$handoffText = Get-FileText -Path $handoffPath
	if ($handoffText -notmatch 'fresh successful compile') {
		$missing += 'skills/svn-delivery-handoff/SKILL.md missing fresh successful compile'
	}
	if ($handoffText -notmatch 'Validation evidence|Fresh successful compile evidence') {
		$missing += 'skills/svn-delivery-handoff/SKILL.md missing validation evidence text'
	}

	$readmeText = Get-FileText -Path (Join-Path $repoRoot 'README.md')
	$exactCommand = 'powershell -ExecutionPolicy Bypass -File scripts/verify-toolkit.ps1'
	if ($readmeText -notmatch [regex]::Escape($exactCommand)) {
		$missing += 'README.md missing exact verification command'
	}

	Assert-Condition ($missing.Count -eq 0) ($missing -join '; ')
}

Invoke-ToolkitCheck 'published docs are marked human-facing and not sole runtime authority' {
	$checks = @(
		@{
			Path = 'README.md'
			Pattern = 'Published docs are human-facing only; runtime authority stays in plugin assets'
		},
		@{
			Path = 'docs/operator/quickstart.md'
			Pattern = 'Runtime authority still lives in plugin assets'
		},
		@{
			Path = 'docs/upstream-mapping.md'
			Pattern = 'internal maintainer provenance only'
		},
		@{
			Path = 'docs/workflow/request-lifecycle.md'
			Pattern = 'Runtime authority still lives in plugin assets'
		}
	)

	$missing = @()
	foreach ($check in $checks) {
		$text = Get-FileText -Path (Join-Path $repoRoot $check.Path)
		if ($text -notmatch [regex]::Escape($check.Pattern)) {
			$missing += "$($check.Path) missing $($check.Pattern)"
		}
	}

	Assert-Condition ($missing.Count -eq 0) ($missing -join '; ')
}

Invoke-ToolkitCheck 'command docs align with plugin runtime authorities' {
	$commandChecks = @(
		@{
			Path = 'commands/intake.md'
			Needles = @('gameplay-context-guard', 'task-intake-router', 'pre-plan')
		},
		@{
			Path = 'commands/gp-debug.md'
			Needles = @('gameplay-context-guard', 'task-intake-router', 'debugging-plan', 'systematic-debugging')
		},
		@{
			Path = 'commands/gp-review.md'
			Needles = @('cpp-reviewer', 'gameplay-reviewer')
		},
		@{
			Path = 'commands/svn-handoff.md'
			Needles = @('svn-workspace-discipline', 'svn-delivery-handoff', 'fresh successful compile')
		}
	)

	$missing = @()
	foreach ($commandCheck in $commandChecks) {
		$text = Get-FileText -Path (Join-Path $repoRoot $commandCheck.Path)
		foreach ($needle in $commandCheck.Needles) {
			if ($text -notmatch [regex]::Escape($needle)) {
				$missing += "$($commandCheck.Path) missing $needle"
			}
		}
	}

	Assert-Condition ($missing.Count -eq 0) ($missing -join '; ')
}

Invoke-ToolkitCheck 'cpp reviewer preserves approved project norms' {
	$reviewerPath = Join-Path $repoRoot 'agents/cpp-reviewer.md'
	$text = Get-FileText -Path $reviewerPath
	$forbidden = @(
		'Hungarian notation is a problem',
		'clang-format required',
		'do not use Hungarian notation',
		'Hungarian notation should be removed',
		'ban Hungarian notation'
	)

	$hits = @()
	foreach ($pattern in $forbidden) {
		if ($text -match [regex]::Escape($pattern)) {
			$hits += $pattern
		}
	}

	Assert-Condition ($hits.Count -eq 0) ($hits -join '; ')
}

Invoke-ToolkitCheck 'router fixtures stay in context-card structure' {
	$requiredFields = @(
		@{ Label = 'Gameplay subdomain'; Pattern = '(?m)^Gameplay subdomain:\s*\S'; },
		@{ Label = 'Main entry point'; Pattern = '(?m)^Main entry point:\s*\S'; },
		@{ Label = 'State and lifecycle impact'; Pattern = '(?m)^State and lifecycle impact:\s*\S'; },
		@{ Label = 'Data and config impact'; Pattern = '(?m)^Data and config impact:\s*\S'; },
		@{ Label = 'Event chain and call path'; Pattern = '(?m)^Event chain and call path:\s*\S'; },
		@{ Label = 'Current evidence source'; Pattern = '(?m)^Current evidence source:\s*\S'; },
		@{ Label = 'Risk level'; Pattern = '(?m)^Risk level:\s*\S'; },
		@{ Label = 'Recommended next path'; Pattern = '(?m)^Recommended next path:\s*\S'; }
	)

	$fixtures = @(
		@{
			Path = 'tests/fixtures/router/lightweight.md'
			ExpectedPlan = 'micro-plan'
			RiskPattern = '(?m)^Risk level:\s*low\s*$'
			ExtraPatterns = @('single-domain', 'low-risk')
		},
		@{
			Path = 'tests/fixtures/router/standard.md'
			ExpectedPlan = 'short-plan'
			RiskPattern = '(?m)^Risk level:\s*medium\s*$'
			ExtraPatterns = @('one gameplay subdomain feature', 'regression risk')
		},
		@{
			Path = 'tests/fixtures/router/complex.md'
			ExpectedPlan = 'full-plan'
			RiskPattern = '(?m)^Risk level:\s*high\s*$'
			ExtraPatterns = @('cross-module', 'high')
		},
		@{
			Path = 'tests/fixtures/router/debugging.md'
			ExpectedPlan = 'debugging-plan'
			RiskPattern = '(?m)^Risk level:\s*high\s*$'
			ExtraPatterns = @('unknown root cause', 'log-driven')
		}
	)

	$missing = @()
	foreach ($fixture in $fixtures) {
		$fullPath = Join-Path $repoRoot $fixture.Path
		$text = Get-FileText -Path $fullPath

		foreach ($field in $requiredFields) {
			if ($text -notmatch $field.Pattern) {
				$missing += "$($fixture.Path) missing field: $($field.Label)"
			}
		}

		if ($text -notmatch "(?m)^Recommended next path:\s*$([regex]::Escape($fixture.ExpectedPlan))\s*$") {
			$missing += "$($fixture.Path) has wrong recommended next path"
		}

		if ($text -notmatch $fixture.RiskPattern) {
			$missing += "$($fixture.Path) has wrong risk level"
		}

		foreach ($needle in $fixture.ExtraPatterns) {
			if ($text -notmatch [regex]::Escape($needle)) {
				$missing += "$($fixture.Path) missing $needle"
			}
		}
	}

	Assert-Condition ($missing.Count -eq 0) ($missing -join '; ')
}

Invoke-ToolkitCheck 'cpp review fixtures cover approved and rejected markers' {
	$approvedPath = Join-Path $repoRoot 'tests/fixtures/cpp-review/approved-sample.cpp'
	$rejectedPath = Join-Path $repoRoot 'tests/fixtures/cpp-review/reject-sample.cpp'

	$approved = Get-FileText -Path $approvedPath
	$rejected = Get-FileText -Path $rejectedPath

	$approvedChecks = @(
		@{ Need = '(?m)^using\s+\w+\s*='; Label = 'using alias' },
		@{ Need = '\bm_'; Label = 'm_ prefix' },
		@{ Need = '\bnullptr\b'; Label = 'nullptr' },
		@{ Need = '\boverride\b'; Label = 'override' },
		@{ Need = '\bfinal\b'; Label = 'final' },
		@{ Need = "`t"; Label = 'tab indentation' }
	)

	$rejectedChecks = @(
		@{ Need = '\bNULL\b'; Label = 'NULL' },
		@{ Need = '\btypedef\b'; Label = 'typedef' },
		@{ Need = '(?m)^.*virtual.*override.*$'; Label = 'virtual override misuse' },
		@{ Need = 'm_pBuffer\s*=\s*buffer'; Label = 'lifetime bug' }
	)

	$missing = @()
	foreach ($check in $approvedChecks) {
		if ($approved -notmatch $check.Need) {
			$missing += "approved-sample.cpp missing $($check.Label)"
		}
	}

	foreach ($check in $rejectedChecks) {
		if ($rejected -notmatch $check.Need) {
			$missing += "reject-sample.cpp missing $($check.Label)"
		}
	}

	Assert-Condition ($missing.Count -eq 0) ($missing -join '; ')
}

Invoke-ToolkitCheck 'claude CLI smoke precheck is documented or manually pending' {
	$readmeText = Get-FileText -Path (Join-Path $repoRoot 'README.md')
	Assert-Condition ($readmeText -match [regex]::Escape('claude --plugin-dir I:\CppGameDev')) 'README.md missing plugin smoke-test command'
	Assert-Condition ($readmeText -match [regex]::Escape('/plugin marketplace add foryoung365/CppGameDev')) 'README.md missing marketplace add command'
	Assert-Condition ($readmeText -match [regex]::Escape('/plugin install cpp-mmorpg-gameplay@foryoung365-plugins')) 'README.md missing marketplace install command'

	$claude = Get-Command claude -ErrorAction SilentlyContinue
	if ($null -ne $claude) {
		$versionOutput = & claude --version 2>&1
		Assert-Condition ($LASTEXITCODE -eq 0) 'claude --version failed'
		Assert-Condition (-not [string]::IsNullOrWhiteSpace(($versionOutput | Out-String))) 'claude --version produced no output'
	}
}

$failures = @($script:Results | Where-Object Status -eq 'FAIL')
foreach ($result in $script:Results) {
	if ($result.Status -eq 'PASS') {
		Write-Host "PASS: $($result.Name)"
	} else {
		Write-Host "FAIL: $($result.Name)"
		Write-Host "      $($result.Details)"
	}
}

if ($failures.Count -gt 0) {
	Write-Host ("FAIL: Toolkit verification failed. {0}/{1} checks passed." -f ($script:Results.Count - $failures.Count), $script:Results.Count)
	exit 1
}

Write-Host ("PASS: Toolkit verification passed. {0}/{1} checks passed." -f $script:Results.Count, $script:Results.Count)
exit 0
