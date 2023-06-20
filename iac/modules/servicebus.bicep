param location string
param serviceBusNamespaceName string
param skuName string = 'Standard'
param queueNames array
param topicNames array
param roles array
param disableLocalAuth bool = false
param zoneRedundant bool = false
var deadLetterQueueName = 'dlqfirehose'

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: serviceBusNamespaceName
  location: location
  sku: {
    name: skuName
  }
  properties: {
    disableLocalAuth: disableLocalAuth
    zoneRedundant: zoneRedundant
}
}

resource deadLetterFirehoseQueue 'Microsoft.ServiceBus/namespaces/queues@2018-01-01-preview' = {
  name: deadLetterQueueName
  parent: serviceBusNamespace
  properties: {
    requiresDuplicateDetection: false
    requiresSession: false
    enablePartitioning: false
  }
}

resource queues 'Microsoft.ServiceBus/namespaces/queues@2018-01-01-preview' = [for queueName in queueNames: {
  parent: serviceBusNamespace
  name: queueName
  dependsOn: [
    deadLetterFirehoseQueue
  ]
  properties: {
    forwardDeadLetteredMessagesTo: deadLetterQueueName
  }
}]

resource topics 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' = [for topicName in topicNames: {
  parent: serviceBusNamespace
  name: topicName
}]

resource RoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = [for assignment in roles:{
  name: guid(serviceBusNamespace.name, assignment.RoleDefinitionId, assignment.principalId)
  scope: serviceBusNamespace
  properties: {
    roleDefinitionId: assignment.RoleDefinitionId
    principalId: assignment.principalId
    principalType: assignment.principalType
  }
}]
