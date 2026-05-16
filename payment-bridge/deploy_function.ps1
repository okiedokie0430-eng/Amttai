# Run this script AFTER you have run `appwrite login` successfully

Write-Host "Navigating to the function directory..."
cd appwrite-functions\process-sms-payment

Write-Host "Initializing Appwrite project..."
appwrite init project

Write-Host "Creating the Cloud Function on your server..."
appwrite functions create `
  --function-id "process-sms-payment" `
  --name "Process SMS Payment" `
  --runtime "node-18.0" `
  --execute "any"

Write-Host "Deploying the function code..."
appwrite functions createDeployment `
  --function-id "process-sms-payment" `
  --entrypoint "src/main.js" `
  --code "." `
  --activate true

Write-Host "====================================================="
Write-Host "DEPLOYMENT COMPLETE!"
Write-Host "Next Step: Go to your Appwrite Console Web UI:"
Write-Host "1. Open 'Functions' -> 'Process SMS Payment' -> 'Settings'"
Write-Host "2. Add your environment variables (APPWRITE_API_KEY, DATABASE_ID, etc.)"
Write-Host "====================================================="
