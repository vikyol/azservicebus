module servicebus './modules/servicebus.bicep' = {
  name: 'servicebus'
  params: {
    location: orderReceiver.identity.principalId
    serviceBusNamespaceName: 'superbus'
    skuName: 'Standard'
    queueNames: [
      'regular'
      'priority'
    ]
    topicNames: [
      'Sushi'
      'Pizza'
      'Pasta'
    ]
    roles: [
      {
        roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/090c5cfd-751d-490a-894a-3ce6f1109419'
        principalId: orderReceiver.identity.principalId
        principalType: 'ServicePrincipal'
      }
    ]
  }
}


resource orderReceiver 'Microsoft.Logic/workflows@2019-05-01' existing = {
  name: 'busget'
}


