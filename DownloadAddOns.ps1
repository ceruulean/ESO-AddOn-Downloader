$esoAddonsFolder = "$([Environment]::GetFolderPath("MyDocuments"))\Elder Scrolls Online\live\AddOns"
$localDownloadFolder = "$([Environment]::GetFolderPath("MyDocuments"))\Elder Scrolls Online\live\AddOnsDownload"
$addonIDs = @(3367,7,2161,2932,2218,2633,1643,2143,185,1346,97,57,3034,3356,2534,2382,1146,2275,2079,601,1594,2118,3353,1302,563,517,2241,1508,2171,288,128,2647,1664)


function Get-DownloadLink([int]$FileID) {
    $d = "https://www.esoui.com/downloads/getfile.php?id=$FileID"
    return $d
}

function Retreive-AddOnVersion([int]$FileID) {
    $d = "https://www.esoui.com/downloads/info$FileID"
    $html = Invoke-WebRequest -Uri ($d) -UseBasicParsing

    if ($html.Content -match "Sorry, this is not a valid link any more.") {
        $obj = [PSCustomObject]@{
            ID = $FileID
            Name = "N/A"
            Version = "N/A"
            LastUpdate = "Addon does not exist."
        }
        return $obj
    }

    $html.Content -match '<div id="version">Version: (.+)</div>' | Out-Null
    $version = $matches[1]

    $html.Content -match '<title>(.+)</title>' | Out-Null
    $name = $matches[1].Split(":")[0]

    $html.Content -match '<div id="safe">(.+)</div>' | Out-Null
    $updated = $matches[1]

    $obj = [PSCustomObject]@{
        ID = $FileID
        Name = $name
        Version = $version
        LastUpdate = $updated
    }
    return $obj
}





Write-Host "Thank you for using the ESOUI download script." -ForegroundColor Green
Write-Host "Make sure, you've added your desired AddOn IDs within this script in line 3." -ForegroundColor Green
Write-Host
Write-Host "You have currently $($addonIDs.Count) AddOn selected." -ForegroundColor Green
Write-Host "---MENU---"
Write-Host "`t1)`tRetreive a detailed list of the addons"
Write-Host "`t2)`tDownload and extract all addons"
$input = Read-Host ">"

if($input -eq "1"){
    Write-Host "Parsing ESOUI.com - Please wait..." -ForegroundColor Yellow
    $addons = @()
    ForEach ($id in $addonIDs) {
        $v = Retreive-AddOnVersion -FileID $id
        $addons += $v
    }
    $addons | Out-Default
    Read-Host "Press any key to exit..."
} elseif ($input -eq "2") {
    Write-Host "Checking if the download folder '$localDownloadFolder' exists..."
    if ((Test-Path $localDownloadFolder) -ne $True) {
        Write-Host "Creating the download folder '$localDownloadFolder'..."
        New-Item -ItemType Directory -Force -Path $localDownloadFolder
    }

    Write-Host "Searching and deleting old ZIP files in the download folder..."
    Get-ChildItem -Path $localDownloadFolder -Filter *.zip | ForEach-Object {
    Remove-Item $_.FullName -Force
    }

    Write-Host "Downloading the files..."
    foreach ($id in $addonIDs) {
        $download = Invoke-WebRequest -Uri (Get-DownloadLink -FileID $id) -UseBasicParsing
        if ($download.Content -match "The specified file was not found." -or 
            $download.Content -match "`Cannot download file - No ID was specified!")
            {
                Write-Host "`tError downloading Addon ID $id" -ForegroundColor Red
                continue
            } 

        $fileName = ([System.Net.Mime.ContentDisposition]::new($download.Headers["Content-Disposition"])).FileName
        $file = [System.IO.FileStream]::new((Join-Path -Path $localDownloadFolder -ChildPath $fileName), [System.IO.FileMode]::Create)
        $file.Write($download.Content, 0, $download.RawContentLength)
        $file.Close()
        Write-Host "`tSaved $fileName ($($download.RawContentLength) bytes) to disk."
    }

    Write-host
    Write-Host "Extracting ZIP files to $esoAddonsFolder..."
    Get-ChildItem -Path $localDownloadFolder -Filter *.zip | ForEach-Object {
        Write-Host "`t$($_.Name) extracted."
        Expand-Archive $_.FullName -DestinationPath $esoAddonsFolder -Force
    }
} else {
    Write-Host "Invalid input. Exiting." -ForegroundColor Red
}








