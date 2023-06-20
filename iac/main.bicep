param location string = resourceGroup().location
param serviceBusNamespaceName string = 'orderbus'
param databaseAccountName string = 'orders${uniqueString(resourceGroup().id)}'
param topics array = ['Sushi', 'Pizza', 'Pasta']

module servicebus './modules/servicebus.bicep' = {
  name: 'servicebus'
  params: {
    location: location
    serviceBusNamespaceName: serviceBusNamespaceName
    skuName: 'Standard'
    disableLocalAuth: true
    queueNames: [
      'regular'
      'priority'
    ]
    topicNames: topics
    roles: [
      {
        roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'
        principalId: OrderWorkflow.identity.principalId
        principalType: 'ServicePrincipal'
      }
      {
        roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/69a216fc-b8fb-44d8-bc22-1f3c2cd27a39'
        principalId: OrderWorkflow.identity.principalId
        principalType: 'ServicePrincipal'
      }
      {
        roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'
        principalId: PizzaWorkflow.identity.principalId
        principalType: 'ServicePrincipal'
      }
    ]
  }
}

module orderapi './modules/apim.bicep' = {
  name: 'orderapi'
  params: {
    location: location
    apiManagementServiceName: 'orderapi${uniqueString(resourceGroup().id)}'
    publisherEmail: 'pizza@franscos.com'
    publisherName: 'Franco'
  }
}

resource pizzatopic 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' existing = {
  name: 'orderbus/pizza'
}

resource pizzasub 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  name: 'pizzahandler'
  parent: pizzatopic
  properties: {
  }
}

resource serviceBusConnection 'Microsoft.Web/connections@2018-07-01-preview' = {
  name: 'serviceBusConnection'
  location: location
  properties: {
    displayName: 'serviceBusConnection'
    api:{
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'servicebus') 
      type: 'Microsoft.Web/locations/managedApis'
    }
    overallStatus: 'Ready'
    statuses: [
      {
          status: 'Ready'
      }
    ]
    connectionState: 'Enabled'
    parameterValueSet: {
      name: 'managedIdentityAuth'
      values: {
        namespaceEndpoint: {
          value: 'sb://${serviceBusNamespaceName}.servicebus.windows.net/'
        }
      }
    }
  }
}

resource cosmosDbConnection 'Microsoft.Web/connections@2018-07-01-preview' = {
  name: 'cosmosDbConnection'
  location: location
  properties: {
    displayName: 'cosmosDbConnection'
    api:{
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'documentdb')
    }
    parameterValueSet: {
      name: 'managedIdentityAuth'
      values: {
      }
    }
  }
}

resource OrderWorkflow 'Microsoft.Logic/workflows@2019-05-01' = {
  name: 'OrderWorkflow'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        'When_a_message_is_received_in_a_queue_(auto-complete)': {
          recurrence: {
            frequency: 'Second'
            interval: 30
          }
          evaluatedRecurrence: {
            frequency: 'Second'
            interval: 30
          }
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'servicebus\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/@{encodeURIComponent(encodeURIComponent(\'priority\'))}/messages/head'
            queries: {
              queueType: 'Main'
            }
          }
        }
      }
      actions: {
        Parse_JSON: {
          runAfter: {}
          type: 'ParseJson'
          inputs: {
            content: '@triggerBody()?[\'Properties\']'
            schema: {
              properties: {
                Category: {
                  type: 'string'
                }
                DeliveryCount: {
                  type: 'string'
                }
                EnqueuedSequenceNumber: {
                  type: 'string'
                }
                EnqueuedTimeUtc: {
                  type: 'string'
                }
                ExpiresAtUtc: {
                  type: 'string'
                }
                LockToken: {
                  type: 'string'
                }
                LockedUntilUtc: {
                  type: 'string'
                }
                MessageId: {
                  type: 'string'
                }
                ScheduledEnqueueTimeUtc: {
                  type: 'string'
                }
                SequenceNumber: {
                  type: 'string'
                }
                Size: {
                  type: 'string'
                }
                State: {
                  type: 'string'
                }
                TimeToLive: {
                  type: 'string'
                }
                Type: {
                  type: 'string'
                }
              }
              type: 'object'
            }
          }
        }
        Switch: {
          runAfter: {
            Parse_JSON: [
              'Succeeded'
            ]
          }
          expression: '@body(\'Parse_JSON\')?[\'Category\']'
          cases: {
            Case: {
              case: 'Sushi'
              actions: {
                Send_message: {
                  runAfter: {}
                  type: 'ApiConnection'
                  inputs: {
                    body: {
                      Properties: '@body(\'Parse_JSON\')?[\'Type\']'
                      SessionId: '@triggerBody()?[\'SessionId\']'
                    }
                    host: {
                      connection: {
                        name: '@parameters(\'$connections\')[\'servicebus\'][\'connectionId\']'
                      }
                    }
                    method: 'post'
                    path: '/@{encodeURIComponent(encodeURIComponent(\'sushi\'))}/messages'
                    queries: {
                      systemProperties: 'None'
                    }
                  }
                }
              }
            }
            Case_2: {
              case: 'Pizza'
              actions: {
                Send_message_2: {
                  runAfter: {}
                  type: 'ApiConnection'
                  inputs: {
                    body: {
                      Properties: {
                        Time: '@utcNow()'
                        Type: '@body(\'Parse_JSON\')?[\'Type\']'
                        id: '@body(\'Parse_JSON\')?[\'MessageId\']'
                      }
                      SessionId: '@triggerBody()?[\'SessionId\']'
                    }
                    host: {
                      connection: {
                        name: '@parameters(\'$connections\')[\'servicebus\'][\'connectionId\']'
                      }
                    }
                    method: 'post'
                    path: '/@{encodeURIComponent(encodeURIComponent(\'pizza\'))}/messages'
                    queries: {
                      systemProperties: 'None'
                    }
                  }
                }
              }
            }
            Case_3: {
              case: 'Pasta'
              actions: {
                Send_message_3: {
                  runAfter: {}
                  type: 'ApiConnection'
                  inputs: {
                    body: {
                      Properties: '@body(\'Parse_JSON\')?[\'Type\']'
                      SessionId: '@triggerBody()?[\'SessionId\']'
                    }
                    host: {
                      connection: {
                        name: '@parameters(\'$connections\')[\'servicebus\'][\'connectionId\']'
                      }
                    }
                    method: 'post'
                    path: '/@{encodeURIComponent(encodeURIComponent(\'pasta\'))}/messages'
                    queries: {
                      systemProperties: 'None'
                    }
                  }
                }
              }
            }
          }
          default: {
            actions: {}
          }
          type: 'Switch'
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          servicebus: {
            connectionId: serviceBusConnection.id
            connectionName: serviceBusConnection.name
            connectionProperties: {
              authentication: {
                type: 'ManagedServiceIdentity'
              }
            }
            id: '${subscription().id}/providers/Microsoft.Web/locations/${location}/managedApis/servicebus'
          }
        }
      }
    }
  }
}

resource PizzaWorkflow 'Microsoft.Logic/workflows@2019-05-01' = {
  name: 'PizzaWorkflow'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        'When_a_message_is_received_in_a_topic_subscription_(auto-complete)': {
          recurrence: {
            frequency: 'Second'
            interval: 30
          }
          evaluatedRecurrence: {
            frequency: 'Second'
            interval: 30
          }
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'servicebus\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/@{encodeURIComponent(encodeURIComponent(\'pizza\'))}/subscriptions/@{encodeURIComponent(\'pizzahandler\')}/messages/head'
            queries: {
              subscriptionType: 'Main'
            }
          }
        }
      }
      actions: {
        'Create_or_update_document_(V3)': {
          runAfter: {
            Parse_JSON: [
              'Succeeded'
            ]
          }
          type: 'ApiConnection'
          inputs: {
            body: {
              PizzaType: '@body(\'Parse_JSON\')?[\'Type\']'
              Time: '@body(\'Parse_JSON\')?[\'ScheduledEnqueueTimeUtc\']'
              id: '@body(\'Parse_JSON\')?[\'MessageId\']'
            }
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'documentdb\'][\'connectionId\']'
              }
            }
            method: 'post'
            path: '/v2/cosmosdb/@{encodeURIComponent(\'${databaseAccountName}\')}/dbs/@{encodeURIComponent(\'orders\')}/colls/@{encodeURIComponent(\'orderspizza\')}/docs'
          }
        }
        Parse_JSON: {
          runAfter: {}
          type: 'ParseJson'
          inputs: {
            content: '@triggerBody()?[\'Properties\']'
            schema: {
              properties: {
                DeliveryCount: {
                  type: 'string'
                }
                EnqueuedSequenceNumber: {
                  type: 'string'
                }
                EnqueuedTimeUtc: {
                  type: 'string'
                }
                ExpiresAtUtc: {
                  type: 'string'
                }
                LockToken: {
                  type: 'string'
                }
                LockedUntilUtc: {
                  type: 'string'
                }
                MessageId: {
                  type: 'string'
                }
                ScheduledEnqueueTimeUtc: {
                  type: 'string'
                }
                SequenceNumber: {
                  type: 'string'
                }
                Size: {
                  type: 'string'
                }
                State: {
                  type: 'string'
                }
                TimeToLive: {
                  type: 'string'
                }
                Type: {
                  type: 'string'
                }
              }
              type: 'object'
            }
          }
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          documentdb: {
            connectionId: cosmosDbConnection.id
            connectionName: cosmosDbConnection.name
            connectionProperties: {
              authentication: {
                type: 'ManagedServiceIdentity'
              }
            }
            id: '${subscription().id}/providers/Microsoft.Web/locations/${location}/managedApis/documentdb'
          }
          servicebus: {
            connectionId: serviceBusConnection.id
            connectionName: serviceBusConnection.name
            connectionProperties: {
              authentication: {
                type: 'ManagedServiceIdentity'
              }
            }
            id: '${subscription().id}/providers/Microsoft.Web/locations/${location}/managedApis/servicebus'
          }
        }
      }
    }
  }
}

resource databaseAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: databaseAccountName
  location: location
  kind: 'GlobalDocumentDB'
  identity: {
    type: 'None'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    isVirtualNetworkFilterEnabled: false
    virtualNetworkRules: []
    disableKeyBasedMetadataWriteAccess: false
    enableFreeTier: true
    enableAnalyticalStorage: false
    analyticalStorageConfiguration: {
      schemaType: 'WellDefined'
    }
    databaseAccountOfferType: 'Standard'
    defaultIdentity: 'FirstPartyIdentity'
    networkAclBypass: 'None'
    disableLocalAuth: false
    enablePartitionMerge: false
    minimalTlsVersion: 'Tls12'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
      maxIntervalInSeconds: 5
      maxStalenessPrefix: 100
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    cors: []
    capabilities: []
    ipRules: []
    backupPolicy: {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: 240
        backupRetentionIntervalInHours: 8
        backupStorageRedundancy: 'Geo'
      }
    }
    networkAclBypassResourceIds: []
    capacity: {
      totalThroughputLimit: 400
    }
  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-04-15' = {
  parent: databaseAccount
  name: 'orders'
  properties: {
    resource: {
      id: 'orders'
    }
  }
}

resource databaseAccountContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-04-15' = {
  parent: database
  name: 'orderspizza'
  properties: {
    resource: {
      id: 'orderspizza'
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
        ]
      }
      partitionKey: {
        paths: [
          '/id'
        ]
        kind: 'Hash'
        version: 2
      }
      uniqueKeyPolicy: {
        uniqueKeys: []
      }
      conflictResolutionPolicy: {
        mode: 'LastWriterWins'
        conflictResolutionPath: '/_ts'
      }
    }
  }
}

resource databaseAccountContributor 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2023-04-15' = {
  parent: databaseAccount
  name: guid('cosmosDbDataContributor', resourceGroup().id, databaseAccount.id)
  properties: {
    roleName: 'Cosmos DB Data Contributor'
    type: 'CustomRole'
    assignableScopes: [
      databaseAccount.id
    ]
    permissions: [
      {
        dataActions: [
          'Microsoft.DocumentDB/databaseAccounts/readMetadata'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/*'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*'
        ]
        notDataActions: []
      }
    ]
  }
}

resource databaseAccountsRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2023-04-15' = {
  parent: databaseAccount
  name: guid('SqlRoleAssignment', resourceGroup().id, databaseAccount.id)
  properties: {
    roleDefinitionId: databaseAccountContributor.id
    principalId: PizzaWorkflow.identity.principalId
    scope: databaseAccount.id
  }
}
