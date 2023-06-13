param location string = resourceGroup().location
param serviceBusNamespaceName string = 'myapp${uniqueString(resourceGroup().id)}'
param skuName string = 'Basic'

param queueNames array = [
  'regular'
  'priority'
]

param topicNames array = [
  'Sushi'
  'Pizza'
  'Pasta'
]

var deadLetterQueueName = 'dlqfirehose'

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2018-01-01-preview' = {
  name: serviceBusNamespaceName
  location: location
  sku: {
    name: skuName
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
