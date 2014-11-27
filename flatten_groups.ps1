# For each configured source-target Active Directory group pair script recursively copies user accounts from a source group and member subgroups to a single flat target group.
# User accounts that are not members of source group tree are removed from target group.
#
# Usage: flatten_groups.ps1 <config file> [-Verbose]
#
# Config file is a CSV file with source-target group pairs separated with comma:
#   source_group1, target_group1
#   source_group2, target_group2
#
# Matvey Marinin 2014
#
[CmdletBinding()]
Param(
    [parameter(
		Mandatory=$true,
		HelpMessage="CSV file with source-target group pairs")]
    [string] $config_file
)
$ErrorActionPreference = "Stop"


Function FlattenADGroup
{
Param(
    [parameter(Mandatory=$true)]
    [string] $source,
    [parameter(Mandatory=$true)]
    [string] $target
)

    #Check if target group is not member of any group (to prevent accidental wrong group overwrite)
    if (Get-ADPrincipalGroupMembership -Identity $target) {
        Write-Error "ERROR: Target group should not be member of any groups, check source and target group names!"
        Exit 1
    }

    $current = Get-ADGroupMember -Identity $target
    $shouldbe = Get-ADGroupMember -Recursive -Identity $source

    if (-not $current) { Write-Verbose "Group $($target) is empty"; $current = @() }
    if (-not $shouldbe) { Write-Verbose "Group $($source) is empty"; $shouldbe = @() }

    #сравниваем две группы
    Write-Verbose "Comparing $($source) и $($target):"
    Compare-object -referenceobject $current -differenceobject $shouldbe | % { Write-Verbose -Message ("{0} {1}" -f  $_.InputObject.Name, $_.SideIndicator) }

    #новых пользователей из source добавить в группу target
    $users_to_add = Compare-object -passthru -referenceobject $current -differenceobject $shouldbe | Where-Object {$_.SideIndicator -eq '=>'}
    if ($users_to_add -ne $null) {
      Write-Verbose "Adding users to $($target)"
      $users_to_add | Add-ADPrincipalGroupMembership -MemberOf $target -Confirm:$False
    } 

    #лишних пользователей удалить из группы target
    $users_to_remove = Compare-object -passthru -referenceobject $current -differenceobject $shouldbe | Where-Object {$_.SideIndicator -eq '<='}
    if ($users_to_remove -ne $null) {
      Write-Verbose "Removing users from $($target)"
      $users_to_remove | Remove-ADPrincipalGroupMembership -MemberOf $target -Confirm:$False
    } 

    #проверочный вывод
    #Compare-object -referenceobject $(Get-ADGroupMember -Identity $target) -differenceobject $(Get-ADGroupMember -Recursive -Identity $source) | % { Write-Verbose -Message ("{0} {1}" -f  $_.InputObject.Name, $_.SideIndicator) }

    #Write-Verbose "[exit] FlattenADGroup $($source) $($target)"
}


# Main script
$groups = Import-Csv -Path $config_file -Header Source, Target
if ($groups) {
    $groups | % {
        FlattenADGroup $_.Source $_.Target 
    }
 } else {
    Write-Error "Config file $($config_file) is empty!"
    Exit 2
 }
