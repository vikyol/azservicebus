import asyncio
from azure.servicebus.aio import ServiceBusClient
from azure.servicebus import ServiceBusMessage
from azure.identity.aio import DefaultAzureCredential

FULLY_QUALIFIED_NAMESPACE = "superbus.servicebus.windows.net"
QUEUE_NAME = "priority"

credential = DefaultAzureCredential()

async def send_single_message(sender):
    # Create a Service Bus message and send it to the queue
    message = ServiceBusMessage("Single Message", application_properties={'Category':'Pizza', 'Type': 'Margherita'},)
    message.application_properties
    await sender.send_messages(message)
    print("Sent a single message")


async def send_a_list_of_messages(sender):
    # Create a list of messages and send it to the queue
    messages = [ServiceBusMessage("Message in list") for _ in range(5)]
    await sender.send_messages(messages)
    print("Sent a list of 5 messages")


async def send_batch_message(sender):
    # Create a batch of messages
    async with sender:
        batch_message = await sender.create_message_batch()
        for _ in range(10):
            try:
                # Add a message to the batch
                batch_message.add_message(ServiceBusMessage("Message inside a ServiceBusMessageBatch"))
            except ValueError:
                # ServiceBusMessageBatch object reaches max_size.
                # New ServiceBusMessageBatch object can be created here to send more data.
                break
        # Send the batch of messages to the queue
        await sender.send_messages(batch_message)
    print("Sent a batch of 10 messages")    


async def run():
    # create a Service Bus client using the credential
    async with ServiceBusClient(
        fully_qualified_namespace=FULLY_QUALIFIED_NAMESPACE,
        credential=credential,
        logging_enable=True) as servicebus_client:
        # get a Queue Sender object to send messages to the queue
        sender = servicebus_client.get_queue_sender(queue_name=QUEUE_NAME)
        async with sender:
            # send one message
            await send_single_message(sender)
            # send a list of messages
            #await send_a_list_of_messages(sender)
            # send a batch of messages
            #await send_batch_message(sender)

        # Close credential when no longer needed.
        await credential.close()


asyncio.run(run())
print("Done sending messages")
print("-----------------------")            