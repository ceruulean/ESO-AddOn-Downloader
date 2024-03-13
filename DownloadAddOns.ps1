$esoAddonsFolder = "$([Environment]::GetFolderPath("MyDocuments"))\Elder Scrolls Online\live\AddOns"
$localDownloadFolder = "$([Environment]::GetFolderPath("MyDocuments"))\Elder Scrolls Online\live\AddOnsDownload"
$previouslyDownloaded = "$localDownloadFolder\downloadedaddons.csv"

$addonIDs = @(
3418, # Synced Account Settings
1536, # Action Duration Reminder
2218, # Bandit's Gear Manager
1174, #Votan's Keybinder
2273, #HideGroup

1245, # Tamriel Trade Center
3079, # ShowTTCPrice

1605, #WritWorthy
3317, #LibCharacterKnowledge
695, #AwesomeGuildStore
1346, #Dolgubons LazyWrit Crafter
97, #Dustman to deal with your unwanted items!

1253, # LibAddonKeybinds
7, # LibAddonMenu
3346, #LibAddonMenu - SoundSlider Widget
2125, # LibAsync
2382, #LibChatMessages
3805, #LibChatMenuButton
2528, #LibCombat
1146, #LibCustomMenu
3297, # LibDataShare
2277, #LibDateTime
2275, #LibDebugLogger
2276, #LibGetText
601, #LibGPS
584, #LibHarvensAddonsSettings
1594, #LibLazyCrafting
2118, #LibMainMenu-2.0
3353, #LibMapData
1302, #LibMapPing
563, #LibMapPins
56, #LibMediaProvider
2204, #LibPrice
2274, #LibPromises
1151, # LibScroll
2241, #LibSets
1311, #LibTextFilter

818, #LuiExtended
93, # pChat
185, # CustomCompassPins
1881, #Map Pins
1399, # Votan's Minimap
1703, # Circular Votan's Mini Map
1255, # Better Rally

3639 # Crux Counter (Arcanist class)
2892, # Pithka's Achievement Tracker
3340, # Gear Overview
3648, # SuperStar
1319, # Improved Death Recap
2918, # Perfect Weave
2048, #Light Attack Helper
2063, # WeaponCharger

3395, # Elm's Markers
2834, # OdySupportIcons

655, # Srendarr Buff and Debuff Tracker
1855, # Code's Combat Alerts 
3439, # Combat Alerts Extended
3137, # CrutchAlerts
1355, # RaidNotifier Updated
1101, # Raidificator Trial Arena and Dungeon Timer
2311, # Hodor Reflexes
1360 # Combat Metrics
)
# 2987, # InstantSwap bugged with volendrung
# 2322, # GCD Bar (don't need with LUI)
# 288, #LoreBooks
# 3501, #Simple Skyshards
# eso toolbox: 176

$currentAddons = @()
if ((Test-Path $previouslyDownloaded)) {
	$currentAddons = (Import-Csv -Path $previouslyDownloaded) | Where-Object { $addonIDs -contains $_.ID }
}

function Get-DownloadLink([int]$FileID) {
    $d = "https://www.esoui.com/downloads/getfile.php?id=$FileID"
    return $d
}

function Get-InstalledVersion([int]$FileID) {
	$ver = $currentAddons | Where-Object { $_.ID -eq $FileID } | Select-Object -ExpandProperty Version
	if ($ver -eq $null ) {
		return "0.0"
	}
	return $ver
}

function Get-EmbeddedLibs([string]$dir, [array]$dependencies) {
	$folders = Get-ChildItem -Directory $dir -Recurse | Where-Object { (($_.Name -like "lib*") -and ($_.Name.Length -gt 4)) -or ($dependencies.Name -contains $_.Name) }
	$libs = @()
	ForEach ($f in $folders) {
		$libs += Get-AddonInfo $f.parent.FullName $f.Name
	}
	return $libs
}

function Get-AddonInfo([string]$dir, [string]$name) {
	if (Test-Path "$dir\$name\$name.txt") {
		$c = Get-Content -Path "$dir\$name\$name.txt"
		
		$av = $c | Select-String -Pattern '^## AddOnVersion:\s(\d+)$'
		$addonVersion = ($av.Matches.Groups | Where {$_.Name -eq 1}).Value

		$r = $c | Select-String -Pattern '^## DependsOn:\s(\S*(?:[^\S\r\n])?)*$'
		$deps = ($r.Matches.Groups | Where {$_.Name -eq 1} | Select -ExpandProperty Captures | Where {$_.Length -gt 0}).Value

		return [PSCustomObject]@{
			Name = $name
			AddonVersion = [int]$addonVersion
			
			Dependencies = if ($deps) {
				@($deps | %{
				$hm = [regex]::split($_, '[ \>\<\=]+')
					[PSCustomObject]@{
						Name = $hm[0]
						MinVersion = [int]$hm[1]
					}
				})
			}
		}
	}

	return [PSCustomObject]@{
		Name = $name
	}

}

function Retreive-AddOnVersion([int]$FileID) {
    $d = "https://www.esoui.com/downloads/info$FileID"
    $html = Invoke-WebRequest -Uri ($d) -UseBasicParsing

    if ($html.Content -match "Sorry, this is not a valid link any more.") {
        $obj = [PSCustomObject]@{
            ID = $FileID
            Name = "N/A"
            Version = [version]"0.0"
            LastUpdate = "Addon does not exist."
        }
        return $obj
    }

    $html.Content -match '<div id="version">Version: (.+)</div>' | Out-Null
    $version = $matches[1]

    $html.Content -match '<title>(.+)</title>' | Out-Null
    $name = ($matches[1].Split(":")[0]).Trim()

    $html.Content -match '<div id="safe">(.+)</div>' | Out-Null
    $updated = $matches[1] -replace "Updated: ", ""

    $obj = [PSCustomObject]@{
        ID = $FileID
        Name = $name
        Version = [string]$version
        LastUpdate = $updated
    }
    return $obj
}

Write-Host -ForegroundColor Green @"
Thank you for using the ESOUI download script.
Make sure, you've added your desired AddOn IDs within this script in line 3.

You have currently $($addonIDs.Count) AddOn selected.
"@
Write-Host @"
---MENU---
`t1)`tRetreive a detailed list of the addons
`t2)`tView addon dependencies
`t3)`tDownload and extract all addons
"@
$input = Read-Host ">"

if($input -eq "1"){
    Write-Host "Parsing ESOUI.com - Please wait..." -ForegroundColor Yellow
    $addons = @()
    ForEach ($id in $addonIDs) {
		$installedVersion = Get-InstalledVersion($id)
        $v = Retreive-AddOnVersion -FileID $id
		$v | Add-Member -NotePropertyName InstalledVersion -NotePropertyValue $installedVersion
        $addons += $v
    }
    $addons | Sort -Property Name | Format-Table
    Read-Host "Press any key to exit..."
} elseif ($input -eq "2") {
	$libs = @()
	$embeddedlibs = @()
	$folders = Get-ChildItem -Directory $esoAddonsFolder
	
	Foreach ($name in $folders) {
		$a = Get-AddonInfo $esoAddonsFolder $name
		$libs += $a
		$e = Get-EmbeddedLibs "$esoAddonsFolder\$name" $a.Dependencies
		$embeddedlibs += $e
	}

	Foreach ($addon in $libs) {
		if ($addon.Dependencies) {
			Write-Host $addon.Name
		}


		Foreach ($dep in $addon.Dependencies) {

			$exists = $libs | Where { $_.Name -like $dep.Name }
			$embedded = $embeddedlibs | Where { $_.Name -like $dep.Name }
			if ($exists) {
				if ( $exists.AddonVersion -lt $dep.MinVersion ) {
					Write-Host " |-- $($dep.Name) v$($exists.AddonVersion), minimum required v$($dep.MinVersion)" -ForegroundColor Yellow
				} else {
					Write-Host " |-- $($dep.Name)" -ForegroundColor Green
				}

			} elseif ($embedded) {  
				Write-Host " |-- (embedded) $($dep.Name)" -ForegroundColor DarkGray
			}
			else {
				Write-Host " x-- $($dep.Name) is missing" -ForegroundColor Red
			}

		}
	}
} elseif ($input -eq "3") {
	[Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem')

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
	$addons = @()
	
    foreach ($id in $addonIDs) {
		$v = Retreive-AddOnVersion -FileID $id
		$installedVersion = Get-InstalledVersion($id)
		
		if ($installedVersion -ne $v.Version) {
							
			$download = Invoke-WebRequest -Uri (Get-DownloadLink -FileID $id) -UseBasicParsing
			if ($download.Content -match "The specified file was not found." -or 
				$download.Content -match "`Cannot download file - No ID was specified!")
				{
					Write-Host "`tError downloading Addon ID $id" -ForegroundColor Red
					continue
				} 

			$fileName = ([System.Net.Mime.ContentDisposition]::new($download.Headers["Content-Disposition"])).FileName
			$fullpath = (Join-Path -Path $localDownloadFolder -ChildPath $fileName)
			$file = [System.IO.FileStream]::new($fullpath, [System.IO.FileMode]::Create)
			$file.Write($download.Content, 0, $download.RawContentLength)
			$file.Close()
			Write-Host "`tSaved $fileName ($($download.RawContentLength) bytes) to disk."

			$zf = [IO.Compression.ZipFile]::OpenRead($fullpath)
			$foldername = $zf.Entries[0].FullName -replace '[\\/]?[\\/]$'
			$zf.Dispose()
			# $v | Add-Member -NotePropertyName Folder -NotePropertyValue $foldername

		} else {		
			Write-Host $v.Name"is on the latest version."
		}
			$addons += $v
    }

    Write-host
    Write-Host "Extracting ZIP files to $esoAddonsFolder..."
    Get-ChildItem -Path $localDownloadFolder -Filter *.zip | ForEach-Object {
        Write-Host "`t$($_.Name) extracted."
        Expand-Archive $_.FullName -DestinationPath $esoAddonsFolder -Force
    }
	
	$addons | Export-Csv -Path $previouslyDownloaded
} else {
    Write-Host "Invalid input. Exiting." -ForegroundColor Red
}
