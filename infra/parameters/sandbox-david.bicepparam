using '../main.bicep'

param location = 'eastus2'
param projectName = 'pricing-mlops'
param environmentName = 'sandbox-david'
param owner = 'david'
param costCenter = 'academic'
param workloadResourceGroupName = 'rg-pricing-mlops-sbx-david'
param workloadLifecycle = 'temporary'
param workloadPurpose = 'personal-sandbox'
param workloadEnvironmentTag = 'sandbox'
param sharedOwner = 'team46'

// Set this after the GitHub repo exists, for example:
// param githubRepository = 'tecmx-team46-pricing/pricing-mlops-platform'
param githubRepository = ''
param githubEnvironment = 'sandbox-david'
param enableGithubActionsIdentity = false

// Personal sandboxes should stay cheap and temporary.
param monthlyBudgetAmount = 0
param budgetContactEmails = []

param extraTags = {
  data_classification: 'masked-or-synthetic'
  maturity: 'prototype'
  subscription_strategy: 'single-subscription'
  subscription_name: '<azure-subscription-name>'
  credit_limit_usd: '200'
}
