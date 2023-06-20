import asyncio
import random
from azure.servicebus.aio import ServiceBusClient
from azure.servicebus import ServiceBusMessage
from azure.identity.aio import DefaultAzureCredential

FULLY_QUALIFIED_NAMESPACE = "orderbus.servicebus.windows.net"
QUEUE_NAME = "priority"

credential = DefaultAzureCredential()

category = ['Sushi', 'Pizza', 'Pasta']
menu = {
    'Sushi': ['Nigiri', 'Maki', 'Sashimi'],
    'Pizza': ['Margherita', 'Quattro Formaggi', 'Capricciosa'],
    'Pasta': ['Pesto', 'Carbonara', 'Bolognese']
}

async def submit_single_order(sender):
    # Create a Service Bus message and send it to the queue
    c = 1 #random.randint(0, 2)
    t = random.randint(0, 2)
    message = ServiceBusMessage("Order", application_properties={'Category': category[c], 'Type': menu[category[c]][t]})
    message.application_properties
    print('Sending message')
    await sender.send_messages(message)
    print("Sent an order: ", category[c], menu[category[c]][t])


async def run():
    # create a Service Bus client using the credential
    async with ServiceBusClient(
        fully_qualified_namespace=FULLY_QUALIFIED_NAMESPACE,
        credential=credential,
        logging_enable=True) as servicebus_client:
        # get a Queue Sender object to send messages to the queue
        print('Run...')

        sender = servicebus_client.get_queue_sender(queue_name=QUEUE_NAME)
        async with sender:
            # send one message
            print('Sending message.......')
            await submit_single_order(sender)

        # Close credential when no longer needed.
        await credential.close()


asyncio.run(run())
print("Done sending messages")
print("-----------------------")            