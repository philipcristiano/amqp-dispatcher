import asyncio
import traceback

from amqpdispatcher.amqp_proxy import AMQPProxy
from amqpdispatcher.logging import getLogger

logger = getLogger(__name__)


class Consumer(object):
    def __init__(self) -> None:
        logger.info("I've been primarily initialized!")

    async def consume(self, amqp: AMQPProxy, msg):
        logger.debug("Consuming primary message:".format(msg.body))

        await amqp.publish("amq.direct", "dead_rk", {}, b"New body!")
        await asyncio.sleep(3)

        logger.debug(
            "Done primary sleeping {0}".format(amqp._message.raw_message.delivery_tag)
        )
        await amqp.ack()

    async def shutdown(self, exception=None):
        if exception is not None:
            logger.error(traceback.format_exc())
        else:
            logger.debug("Shut down primary worker cleanly")
