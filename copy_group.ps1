[CmdletBinding()]
Param(
    [parameter(
		Mandatory=$true,
		HelpMessage="Source group")]
    [string] $source,

    [parameter(
		Mandatory=$true,
		HelpMessage="Target group")]
    [string] $target
)

#
# Script recursively copies source Active Directory group members (and child group members) to target flat AD group.
# Accounts which are not members of source group tree are removed from target group.
#
# Usage: copy_group.ps1 "Regions-Development" "AAAS-Net-Region-DEV" [-Verbose]
#
# Matvey Marinin 2014
#

$ErrorActionPreference = "Stop"

Write-Verbose "Connecting to Active Directory..."

$current = Get-ADGroupMember -Identity $target
$shouldbe = Get-ADGroupMember -Recursive -Identity $source

#сравниваем две группы
Write-Verbose "Comparing $($source) и $($target):"
Compare-object -referenceobject $current -differenceobject $shouldbe | % { Write-Verbose -Message ("{0} {1}" -f  $_.InputObject.Name, $_.SideIndicator) }

#новых пользователей из source добавить в группу target
$users_to_add = Compare-object -passthru -referenceobject $current -differenceobject $shouldbe | Where-Object {$_.SideIndicator -eq '=>'}
if ($users_to_add -ne $null) {
  Write-Verbose "Adding users to $($target)"
  Add-ADPrincipalGroupMembership -Identity $users_to_add -MemberOf $target -Confirm:$False
} 

#лишних пользователей удалить из группы target
$users_to_remove = Compare-object -passthru -referenceobject $current -differenceobject $shouldbe | Where-Object {$_.SideIndicator -eq '<='}
if ($users_to_remove -ne $null) {
  Write-Verbose "Removing users from $($target)"
  Remove-ADPrincipalGroupMembership -Identity $users_to_remove -MemberOf $target -Confirm:$False
} 

#проверочный вывод
Compare-object -referenceobject $(Get-ADGroupMember -Identity $target) -differenceobject $(Get-ADGroupMember -Recursive -Identity $source) | % { Write-Verbose -Message ("{0} {1}" -f  $_.InputObject.Name, $_.SideIndicator) }

