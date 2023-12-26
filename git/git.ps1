# Register the custom completion script for a specific parameter of a command
Register-ArgumentCompleter -CommandName 'git' -ScriptBlock {
    param(
            $WordToComplete,
            $CommandAst,
            $CursorPosition
        )


    $word = $WordToComplete.Replace('"', '""')
    $elements = $CommandAst.CommandElements | ForEach-Object { $_.Extent.Text }

    if (($elements.Count -eq 1) -or ($word -and $elements.Count -eq 2)){
        # completion of the git subcommand itself (branch, checkout, pull, ... etc)
        
        # Grab all possible git subcommands from the help page and extract the 
        # command and the description part
        $completions = $(git help -a | 
            Where-Object -FilterScript { $_.StartsWith("  ") -and -not $_.Trim().StartsWith("[") } |
            ForEach-Object {
                $tokens = $_.Trim().Split(" ").Where({ $_.Count -gt 0 }) 

                [PSCustomObject]@{
                    Command = $tokens[0]
                    Description = [System.String]::Join(" ", $tokens[1..($tokens.Count - 1)])
                }
            })

        $filteredCompletions = $completions | 
            Where-Object { $_.Command -like "${word}*" } | 
            ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_.Command, $_.Command, 'ParameterValue', $_.Description)
            }

        $filteredCompletions
           
    } else {
        # completions of the options of a git subcommand

        $module = $elements[1]
        $helpContent = Invoke-Expression "git $module -h 2>&1" | ForEach-Object { $_.ToString() }
        $filteredCompletions = @()


        $usageLines = $helpContent | Where-Object { $_.Trim() -match "^(usage|or):" }

        # if the command ca have a branch name as argument, we need the current available
        # list of all branches and put that into the result list
        if ($usageLines | Select-String "branch>"){
            $filteredCompletions += $(git branch -l) |
                ForEach-Object { 
                    $branch = $_.Replace("*","").Trim()
                    [System.Management.Automation.CompletionResult]::new($branch, $branch, 'ParameterValue', "local branch $branch")
                }
        }

        # from the help page of the subcommand we can parse all available options
        # of this git subcommand
        $completions = $helpContent | 
            ForEach-Object {$_.Trim()} | 
            Where-Object -FilterScript { $_.Trim().StartsWith("-") -and $_.Trim().Contains($word)} |
            ForEach-Object {
                if($_ -match "(?<short>-[\w\d]+)?,?\s*(?<long>--[\w\d-]+)?\s*(?<description>.+)?") {
                    [PSCustomObject]@{
                        Command = if ($Matches.Short) { $Matches.Short } else { $Matches.Long }
                        Short = $Matches.short
                        Long = $Matches.long
                        Description = if ($Matches.description) { $Matches.description } else { "/" }
                    }
                }
            } 

        $filteredCompletions += $completions |
            
            ForEach-Object {
                [System.Management.Automation.CompletionResult]::new(
                    $_.Command,
                    "$($_.Short) $($_.Long)".Trim(), 
                    'ParameterValue',
                    $_.Description
                )
            }
            
        $filteredCompletions
        
    }
}
