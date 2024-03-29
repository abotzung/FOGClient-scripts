# Script par Alexandre BOTZUNG (Alexandre.BOTZUNG@GrandEst.fr) - Jul 2021...Feb 2023
# 
# Ce script permet d'automatiser le redémarrage du poste en UEFI si une tâche dans FOG est détectée.
# Il fonctionne en coopération de Zazzles.dll, dont la fonction "InitiateSystemShutdownEx" a été patchée en "InitiateUEFIBeforeReboot"
#   et syreboot.dll intercepte l'appel et lance le script kivabien + renvoie l'appel de la fonction initiale vers Advapi32.dll
#
# Un système de scripts utilisateurs à été mis en place. Pour cela, créez le dossier "prereboot" dans le dossier d'installation de FOG.
#   Et ajoutez vos scripts _POWERSHELL_ (*.ps1) dans celui-ci. Lors d'un remastérisation (up/down) ceux-ci vont être exécutés par ordre alphabétique.
#     (Exemple, pour réaliser un nettoyage automatique du système avant capture, déployer des drivers, ...)
#
#
# ATTENTION : Ce script est basée sur la langue Française. Il n'est pas capable de fonctionner correctement 
#			  sur une langue différente. ('description*', 'identificateur*')
# Une piste ? : https://github.com/wandersick/englishize-cmd

param (
	[Parameter(Mandatory=$false)]$RunMe # Indique si on débug le script ou non
)

# Démarre l'enregistrement du script dans %windir%\logs
$logpath="$($Env:windir)\logs\"
Start-Transcript -Path "$($logpath)FOG_prereboot.log"

if ("$RunMe" -eq "yes") { $IsDebug=0 } else { Write-Output " ----- ----- MODE DEBUG ('-RunMe yes' pour OUTREPASSER le mode débug) ----- ----- "; $IsDebug=1 }

# Change (ajoute) sysnative dans le Path de Powershell (subtilitée WoW64 / équivalent à System32)
$env:Path += ';'+$Env:windir+'\sysnative'

if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
[Security.Principal.WindowsBuiltInRole] "Administrator")) {
	throw "Permissions insuffisantes, merci de l'executer avec des droits administrateur"
	exit 1
}

# Récupère dans le registre, le chemin du service FOG
try
{
	$FOGSvcExec = (Get-ItemPropertyValue -Path Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\FOGService -Name ImagePath)
	$FOGSvcExec = $FOGSvcExec -replace '"',''
	$FOGSvcPath = Split-Path -Path $FOGSvcExec
	$FOGSvcPath = $FOGSvcPath+'\'
	$FOGSvcConfig = "$($FOGSvcPath)settings.json"
	Write-Output "Chemin du service : $FOGSvcExec"
	Write-Output "Dossier du client FOG : $FOGSvcPath"
	Write-Output "Chemin du fichier de Configuration : $FOGSvcConfig"
}
catch
{
	Throw "FOG Client n'a pas été trouvée sur ce système."
	exit 1
}
# Essaye de déterminer si Secure Boot est actif
try
{
	$UEFI_ISSecureBootActivated = (Get-ItemPropertyValue -Path Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecureBoot\State -Name UEFISecureBootEnabled)
}
catch
{
	Write-Output "ATTENTION ; Je n'arrive pas à lire l'état de Secure Boot"
}
if ("$UEFI_ISSecureBootActivated" -eq "1") { $UEFI_ISSecureBootActivated="OUI" } else { $UEFI_ISSecureBootActivated="NON" }

### PARTIE 1 - Va chercher le fichier de config. de FOG pour en extraire l'adresse IP du serveur, ainsi que la racine du serveur web (généralement /fog) ###################
try
{
    $out = Get-Content -Path $FOGSvcConfig
    $out = $out -replace '\s+',''
    $out = $out -replace '`t',''
    $out = $out -replace '`n',''
    $out = $out -replace '`r',''
    $out = $out -replace '\"',''
    $out = $out -replace ',',''
    $out = $out -replace '}',''
    $out = $out -replace '{',''

    if( -Not $out -like '*Server:*')
    {
        Write-output "ERREUR : Pas de variable Server trouvé dans le fichier $FOGSvcConfig"
        Throw "ERREUR : Pas de variable 'Server:' trouvé dans le fichier $FOGSvcConfig"
		exit 1
    }
}
Catch
{
	Write-output "ERREUR lors de l'analyse du fichier : $FOGSvcConfig"
	Throw "ERREUR lors de l'analyse du fichier : $FOGSvcConfig"
	exit 1
}

$FOGproto=0
For($i=0;$i -lt $out.Count;$i++)
{
    if($out[$i] -like '*Server:*')
    {
        $FOGserver=$out[$i].substring(7)
    }
    if($out[$i] -like '*WebRoot:*')
    {
        $FOGwebroot=$out[$i].substring(8)
    }
    if($out[$i] -like '*HTTPS:*')
    {
        $FOGproto=$out[$i].substring(6)
    }
}

if ($FOGproto -eq 1){ $FOGproto="https" } else { $FOGproto="http" }

# URI de FOG
$FOGURI=$FOGproto+"://"+$FOGserver+$FOGwebroot

Write-output "URI FOG : $FOGURI"

### PARTIE 2 - Normalement, à cette étape, je possède l'URI complète de FOG. Je vais query le serveur avec mon adresse MAC pour savoir si il y une tâche en attente. ##############
##### NOTE : C'est la même API qui est utilisée par iPXE #####

####https://stackoverflow.com/questions/34422255/trying-to-do-a-simple-post-request-in-powershell-v2-0-no-luck

try 
{
	$GLOBAL_ComputerName = (Get-WmiObject Win32_OperatingSystem).CSName
	$GLOBAL_AdresseIPUser = (Test-Connection -ComputerName $GLOBAL_ComputerName -count 1).ipv4address.IPAddressToString
	$GLOBAL_MACAddress = (gwmi -ComputerName $GLOBAL_ComputerName -Class Win32_NetworkAdapterConfiguration | where {$_.IPAddress -like $GLOBAL_AdresseIPUser}).MACAddress

	$url = $FOGURI + "/service/hostinfo.php"
	$postData = "mac="+$GLOBAL_MACAddress

	$buffer = [text.encoding]::ascii.getbytes($postData)

	[net.httpWebRequest] $req = [net.webRequest]::create($url)
	$req.method = "POST"
	$req.AllowAutoRedirect = $false
	$req.ContentLength = $buffer.length
	$req.TimeOut = 10000
	$req.KeepAlive = $false
	$reqst = $req.getRequestStream()
	$reqst.write($buffer, 0, $buffer.length)
	$reqst.flush()
	$reqst.close()
	[net.httpWebResponse] $res = $req.getResponse()
	$resst = $res.getResponseStream()
	$sr = new-object IO.StreamReader($resst)
	$result = $sr.ReadToEnd()
	$res.close()
}
catch
{
	Write-output "ERREUR : Impossible de contacter le serveur FOG." 
	Write-output " -> Est-ce un problème d'exception proxy ? Essayez d'ajouter l'IP dans la liste des exceptions"
	Write-output " -> Le serveur est-il allumée ?"
	Write-output " -> Le service web est peut-être tombée. Essayez de le redémarrer."
	throw "ERREUR : Impossible de contacter le serveur FOG." 
	exit 1
}

#### ETAPE 3 - On a normalement une réponse, et on agis en conséquence. ###########
##### NOTE : La réponse pour l'action est "positive". c.a.d que si une partie du script échoue, par défaut, on ne fera rien au poste.

if(($result -like '*export storage*') -and ($result -like '*export imagepath*'))
{
    Write-output "Ok, on à une tâche en attente (type down/up), faut qu'on sorte le poste du domaine + redémarrage PXE`r`n"
	
	if (Test-Path -Path "$($FOGSvcPath)prereboot\")
	{
		Write-Host " ----- Exécution des scripts personnalisés -----`r`n"
		$ListeDesScripts=(Get-ChildItem -Path "$($FOGSvcPath)prereboot\" -Filter "*.ps1" | Sort-Object).Name
		foreach($Script in $ListeDesScripts)
		{
			Write-Host " ----- Execute : $($FOGSvcPath)prereboot\$($Script)"
			if ($IsDebug -eq 0) { & "$($FOGSvcPath)\prereboot\$($Script)" }
		}
		Write-Host " ----- FIN DE L'EXECUTION ------"
	} else {
		Write-Host " INFO : Le dossier est absent : $($FOGSvcPath)prereboot\ "
	}
	
	$out = (bcdedit.exe /enum firmware)
	Write-output $out
	
	$out = $out + "`r`n---------------"

	$out = $out -replace '\s+',''
	$out = $out -replace '`t',''
	$out = $out -replace '`n',''
	$out = $out -replace '`r',''
	$out = $out.trim()
	$out = $out.trimEnd()
	$out = $out.trimStart()
	$out = $out -replace ' ',''
	$out = $out.ToLower()

	$UEFI_actif=0
	if($out -like '*{fwbootmgr}*')
	{
		Write-output "Ok, UEFI est activé (SecureBoot:$UEFI_ISSecureBootActivated)`r`n"
		$UEFI_actif=1
	} else {
		Write-output "ERREUR : UEFI ne semble pas actif."
		Write-output $out
		$UEFI_actif=0
	}

	if ($UEFI_actif -eq 1)
	{
		# Exécution 'à vide' ; On teste les entrées habituelles. Si l'on trouve rien, je serai plus clément && prendrai 'le premier venu'
		$unID=0
		$UEFI_desc=''
		$UEFI_iden=''
		$description=''
		$identificateur=''
		For($i=0;$i -lt $out.Count;$i++)
		{
			if($out[$i] -like '*-----*') {
			   
				if(($description -like '*nic*') -or
				   ($description -like '*ip4*') -or
				   ($description -like '*ether*') -or
				   ($description -like '*pxe*') -or
				   ($description -like '*ipv4*') -or
				   ($description -like '*gbe*') -or
				   ($description -like '*family*') -or
				   ($description -like '*netw*')
				  )
				{
					if(($description -like '*ip4*') -or ($description -like '*v4*') -or ($description -like '*4*') -and ($unID -eq 0))
					{
						Write-host " (1ère recherche) Je trouve un potentiel candidat: $description -> $identificateur"
						$UEFI_desc=$description
						$UEFI_iden=$identificateur
						$unID=$unID+1
					}

				}
				$description=""
				$identificateur=""
			}

			if($out[$i] -like 'description*') {
				$description=$out[$i].substring(11)
			}

			if($out[$i] -like 'identificateur*') {
				$identificateur=$out[$i].substring(14)
			}
		}	
		
		# ------ Analyse de la 1ère recherche -------
		# (=0) Si l'on a rien trouvé lors de la précédente recherche...
		if ($unID -eq 0) {
			Write-output " -> (1ere recherche) ; Je n'ai RIEN trouvé."
			Write-output " Je relance une 2ème recherche."
			$unID=0
			$UEFI_desc=''
			$UEFI_iden=''
			$description=''
			$identificateur=''
			For($i=0;$i -lt $out.Count;$i++)
			{
				if($out[$i] -like '*-----*') {
					if(($description -like '*nic*') -or
					   ($description -like '*ip4*') -or
					   ($description -like '*ether*') -or
					   ($description -like '*pxe*') -or
					   ($description -like '*ipv4*') -or
					   ($description -like '*gbe*') -or
					   ($description -like '*family*') -or
					   ($description -like '*netw*')
					  )
					{
						if($unID -eq 0)
						{
							Write-host " (2ème recherche) : Je trouve un potentiel candidat: $description -> $identificateur"
							$UEFI_desc=$description
							$UEFI_iden=$identificateur
							$unID=$unID+1
						}
					}
					$description=""
					$identificateur=""
				}

				if($out[$i] -like 'description*') {
					$description=$out[$i].substring(11)
				}

				if($out[$i] -like 'identificateur*') {
					$identificateur=$out[$i].substring(14)
				}
			}
			if ($unID -gt 0){
				# (>0) On a trouvé(s) quelque-chose. On le définis comme entrée temporaire dans le chargeur de démarrage.
				Write-output " -> (2ème recherche) ; $unID entrée(s) trouvé(s) : $UEFI_desc -> $UEFI_iden"
				if ($IsDebug -eq 0) { bcdedit.exe /set "{fwbootmgr}" bootsequence $UEFI_iden }
			} else {
				Write-output "`r`n`r`n !!! IMPOSSIBLE DE TROUVER L'ENTREE DE DEMARRAGE RESEAU !!!"
				Write-output "Merci de contacter le développeur à alexandre.botzung@grandest.fr avec les informations ci-dessous : "
				Write-output "----------><8------8><-----------"
				$unID=0
				$UEFI_desc=''
				$UEFI_iden=''
				$description=''
				$identificateur=''
				For($i=0;$i -lt $out.Count;$i++)
				{
					if($out[$i] -like '*-----*') {
						Write-output "-> TROUVE DESC:$description IDEN:$identificateur"
						$unID=$unID+1

						$description=""
						$identificateur=""
					}

					if($out[$i] -like 'description*') {
						$description=$out[$i].substring(11)
					}

					if($out[$i] -like 'identificateur*') {
						$identificateur=$out[$i].substring(14)
					}
				}
				Write-output "NBR_ENTREES:$unID"
				Write-output "----------><8------8><-----------"
				Write-output " Merci ! Vous m'aiderez à réaliser un script de meilleur qualité. (ou de bonne facture ^^)"
			}
		} elseif ($unID -eq 1){
			# (=1) On a trouvé (lors de la 1ère recherche, 1 seule entrée. On change le bootloader...)
			Write-output " -> (1ere recherche) ; 1 entrée trouvé : $UEFI_desc -> $UEFI_iden"
			if ($IsDebug -eq 0) { bcdedit.exe /set "{fwbootmgr}" bootsequence $UEFI_iden }
		} else {
			# On a trouvé plusieurs entrées, ça craint ! (Traumatized Mr. Incredible.jpg)
			Write-output " -> (1ere recherche) ; PLUSIEURS ($unID) entrées trouvés. Je change vers la dernière trouvée : $UEFI_desc -> $UEFI_iden"
			if ($IsDebug -eq 0) { bcdedit.exe /set "{fwbootmgr}" bootsequence $UEFI_iden }
		}
	} else {
		Write-output " UEFI ne semble pas actif, impossible de changer l'ordre de démarrage."
	}
	
	# ------ Retire la machine du domaine ------ 
	$GLOBAL_ComputerName = (Get-WmiObject Win32_OperatingSystem).CSName
	# On est JAMAIS trop sûr... ^^'
	if ($IsDebug -eq 0) { wmic.exe /interactive:off ComputerSystem Where "Name='$GLOBAL_ComputerName'" Call UnJoinDomainOrWorkgroup FUnjoinOptions=0 }
    if ($IsDebug -eq 0) { wmic.exe /interactive:off ComputerSystem Where "Name='$GLOBAL_ComputerName'" Call UnJoinDomainOrWorkgroup FUnjoinOptions=0 }
    if ($IsDebug -eq 0) { wmic.exe /interactive:off ComputerSystem Where "Name='$GLOBAL_ComputerName'" Call JoinDomainOrWorkgroup name="WORKGROUP" }
    if ($IsDebug -eq 0) { wmic.exe /interactive:off ComputerSystem Where "Name='$GLOBAL_ComputerName'" Call JoinDomainOrWorkgroup name="WORKGROUP" }

	# ------ Un petit message amical pour indiquer que l'on va redémarrer ------
    msg.exe * /TIME:30 /W "Le client FOG va redémarrer l'ordinateur dans 30 secondes pour une remastérisation du poste."
} else {
	# ------ Un petit message amical pour indiquer que l'on va redémarrer ------
    Write-output "FOG est en train de changer le nom de domaine/ajout dans l'AD/...`r`n"
	
	# Correctif pour le ticket PHR22-08063 (gpupdate à réaliser après mise dans le domaine x2)
	if ($IsDebug -eq 0) { gpupdate.exe /FORCE }
	if ($IsDebug -eq 0) { gpupdate.exe /FORCE }
	
	msg.exe * /TIME:30 /W "Le client FOG va redémarrer l'ordinateur dans 30 secondes pour une opération de maintenance."
}
Stop-transcript