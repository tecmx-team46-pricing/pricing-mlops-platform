using '../foundation/main.bicep'

param location = 'eastus2'
param projectName = 'pricing-mlops'
param environmentName = 'staging'
param owner = 'team46'
param costCenter = 'academic'
param workloadResourceGroupName = 'rg-pricing-mlops-staging'
param workloadLifecycle = 'permanent'
param workloadPurpose = 'mlops-staging'
param workloadEnvironmentTag = 'staging'
param sharedOwner = 'team46'

// Set this after the GitHub repo exists, for example:
// param githubRepository = 'tecmx-team46-pricing/pricing-mlops-platform'
param githubRepository = 'tecmx-team46-pricing/pricing-mlops-platform'
param githubEnvironment = 'staging'
param enableGithubActionsIdentity = true
// Existing staging Contributor assignment was created previously with a different role assignment id.
param enableGithubSubscriptionContributor = false
param modelGithubRepository = 'tecmx-team46-pricing/pricing-mlops'
param modelGithubEnvironment = 'staging'
param enableModelGithubActionsIdentity = true
param enableHelloFunction = false
param enableModelContainerJob = true
param modelJobCpu = '0.25'
param modelJobMemory = '0.5Gi'

// The MVP uses the included 200 USD Azure credit in "<azure-subscription-name>".
// Keep the budget below the full credit to leave operating margin.
param monthlyBudgetAmount = 180
param budgetContactEmails = []

param extraTags = {
  data_classification: 'masked-or-synthetic'
  maturity: 'mvp'
  subscription_strategy: 'single-subscription'
  subscription_name: '<azure-subscription-name>'
  credit_limit_usd: '200'
}
