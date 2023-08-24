$release = $env:ubuntu20
$Build = $env:BUILD_BUILDNUMBER
$artifactPath = $env:SYSTEM_ARTIFACTSDIRECTORY
$sourcePath = $env:BUILD_SOURCESDIRECTORY

#Pipeline Variables from variable group
$resource_group = $env:image_resource_group_name
$gallery_name = $env:gallery_name
$subscription = $env:subscription
$build_resource_group_name = $env:build_resource_group_name
$virtual_network_name = $env:virtual_network_name
$virtual_network_resource_group_name = $env:virtual_network_resource_group_name
$virtual_network_subnet_name = $env:virtual_network_subnet_name


Write-Host $release
$splitString = "$release" -split "/"
$distro = $splitString[0]
$version = $splitString[1]
Write-Output "distro = `"$distro`""
Write-Output "version = `"$version`""

Write-Host "Image RG = `"$resource_group`""
Write-Host "Build RG = `"$build_resource_group_name`""
Write-Host "Subscription = `"$subscription`""
Write-Host "Gallery Name = `"$gallery_name`""
Write-Host "Virtual_network_name = `"$virtual_network_name`""
Write-Host "Virtual_network_resource_group_name = `"$virtual_network_resource_group_name`""
Write-Host "Virtual_network_subnet_name = `"$virtual_network_subnet_name`""

$sourceUrl = "https://github.com/actions/runner-images/archive/refs/tags/$release.zip"


$zipFilePath = "$env:TEMP\$distro-$version.zip"
New-Item -Path $env:TEMP\$distro-$version-$Build-min -ItemType Directory 
$extractPath = "$env:TEMP\$distro-$version-$Build-min-extracted"

Write-Host Dowloading latest release to $zipFilePath
Invoke-WebRequest -Uri $sourceUrl -OutFile $zipFilePath 

Write-Host Extracting release files to  $extractPath
Expand-Archive -Path $zipFilePath -DestinationPath $extractPath -Force



# Moving from temp dir to $artifactPath
Copy-Item -Path "$extractPath\*" -Destination $artifactPath/images/$release -Recurse 

# Removing temp files
Remove-Item -Path $zipFilePath
Remove-Item -Path $extractPath -Recurse

## Copy the Minimal image
Copy-Item $sourcePath/minimal_Images/ubuntu2004.json -Destination $artifactPath/images/$release/images/linux/ubuntu2004_min.json 

## MODIFY THE JSON
cd $artifactPath/images/$release/images/linux
DIR 

$jsonContent = Get-Content -Path "ubuntu2004_min.json" -Raw | ConvertFrom-Json
# Remove variables
$jsonContent.variables.psobject.Properties.Remove("client_id")
$jsonContent.variables.psobject.Properties.Remove("client_secret")
$jsonContent.variables.psobject.Properties.Remove("tenant_id")
$jsonContent.variables.psobject.Properties.Remove("object_id")
$jsonContent.variables.psobject.Properties.Remove("resource_group")
$jsonContent.variables.psobject.Properties.Remove("storage_account")
$jsonContent.variables.psobject.Properties.Remove("temp_resource_group_name")
$jsonContent.variables.psobject.Properties.Remove("location")
$jsonContent.variables.psobject.Properties.Remove("private_virtual_network_with_public_ip")
$jsonContent.variables.psobject.Properties.Remove("allowed_inbound_ip_addresses")

# Add azure_tags
$jsonContent.builders[0] | Add-Member -MemberType NoteProperty -Name "azure_tags" -Value @{
    CostCenter = "1116"
    Description = "Azure DevOps Agents"
}
# Add shared_image_gallery_destination
$jsonContent.builders[0] | Add-Member -MemberType NoteProperty -Name "shared_image_gallery_destination" -Value @{
subscription = $subscription
resource_group = $resource_group
gallery_name = $gallery_name
image_name = "ubuntu20_minimal"
image_version = "0.$($version)"
replication_regions = "eastus2"
storage_account_type = "Standard_LRS"
}

# Add variables
$jsonContent.variables | Add-Member -MemberType NoteProperty -Name "managed_image_name" -Value "$($distro)_$($version)"
$jsonContent.variables | Add-Member -MemberType NoteProperty -Name "managed_image_resource_group_name" -Value $resource_group

# Setting up variable values
$jsonContent.variables.build_resource_group_name = $build_resource_group_name
$jsonContent.variables.subscription_id = $subscription
$jsonContent.variables.virtual_network_name = $virtual_network_name
$jsonContent.variables.virtual_network_resource_group_name = $virtual_network_resource_group_name
$jsonContent.variables.virtual_network_subnet_name = $virtual_network_subnet_name
# Remove builders
$jsonContent.builders[0].PSObject.Properties.Remove("private_virtual_network_with_public_ip")
$jsonContent.builders[0].PSObject.Properties.Remove("allowed_inbound_ip_addresses")
$jsonContent.builders[0].PSObject.Properties.Remove("temp_resource_group_name")
$jsonContent.builders[0].PSObject.Properties.Remove("resource_group_name")
$jsonContent.builders[0].PSObject.Properties.Remove("storage_account")
$jsonContent.builders[0].PSObject.Properties.Remove("capture_container_name")
$jsonContent.builders[0].PSObject.Properties.Remove("capture_name_prefix")

# Add builders
$jsonContent.builders[0] | Add-Member -MemberType NoteProperty -Name "managed_image_name" -Value "$($distro)_$($version)_min"
$jsonContent.builders[0] | Add-Member -MemberType NoteProperty -Name "managed_image_resource_group_name" -Value $resource_group

# Save the modified JSON back to the file
$jsonContent | ConvertTo-Json -Depth 100 | Set-Content -Path "ubuntu2004_min-ed.json"

# Output the modified JSON content
$jsonContent
DIR 