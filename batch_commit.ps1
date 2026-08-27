$ErrorActionPreference = "Stop"

$folders = @("6", "12", "20", "2")

foreach ($folder in $folders) {
    Write-Host "`n--- Processing Folder $folder ---"
    
    # USER'S GENIUS IDEA: Ignore all other large folders so `git commit` doesn't hang!
    $ignoreContent = ""
    foreach ($f in $folders) {
        if ($f -ne $folder) {
            $ignoreContent += "$f/`n"
        }
    }
    Set-Content -Path "F:\nta\.gitignore" -Value $ignoreContent
    Write-Host "Updated .gitignore to ignore other large folders..."
    
    $subdirs = @(Get-ChildItem -Path "F:\nta\$folder" -Directory | Select-Object -ExpandProperty Name)
    
    $batchSize = if ($folder -eq "2") { 50 } else { 100 }
    
    $batch = @()
    $batchNum = 1
    foreach ($subdir in $subdirs) {
        $batch += "$folder/$subdir/"
        if ($batch.Count -eq $batchSize) {
            Write-Host "Batch $batchNum (size $batchSize) - Staging..."
            & git add $batch
            
            # Check if there is actually anything to commit (in case it was committed earlier)
            if ((& git status --porcelain) -match "^[A-Z]") {
                Write-Host "Batch $batchNum - Committing..."
                & git commit -q -m "Add $folder (part $batchNum)"
                Write-Host "Batch $batchNum - Pushing..."
                & git push -q
            } else {
                Write-Host "Batch $batchNum - Already committed."
            }
            
            $batch = @()
            $batchNum++
        }
    }
    
    if ($batch.Count -gt 0) {
        Write-Host "Batch $batchNum - Staging remaining subdirs..."
        & git add $batch
        if ((& git status --porcelain) -match "^[A-Z]") {
            Write-Host "Batch $batchNum - Committing..."
            & git commit -q -m "Add $folder (part $batchNum)"
            Write-Host "Batch $batchNum - Pushing..."
            & git push -q
        }
    }
    
    Write-Host "Checking for root files in $folder..."
    & git add "$folder/"
    if ((& git status --porcelain) -match "^[A-Z]") {
        & git commit -q -m "Add remaining files in $folder"
        & git push -q
    }
}

Set-Content -Path "F:\nta\.gitignore" -Value ""
Write-Host "All done! Gitignore restored."
