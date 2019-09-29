TEST_GIT_ROOT="$(git rev-parse --show-toplevel)"
load "${TEST_GIT_ROOT}/tests/utilities/test_utils.bash"

setup() {
    setup_sequence
}

@test "Consumption by Forever Blocking Consumers" {
    NOW_TIMESTAMP=$(date -u +%s)

    docker-compose -f docker-compose.yml -f ./tests/integration/forever-consumption-test.compose-override.yml up -d
    dockerize -wait tcp://localhost:5672 -timeout 15s

    ( docker logs -f amqp-dispatcher_dispatcher_1 --since "$NOW_TIMESTAMP" 2>&1 & ) | grep -q "all consumers of class ForeverConsumer created"
    ( docker logs -f amqp-dispatcher_dispatcher_1 --since "$NOW_TIMESTAMP" 2>&1 & ) | grep -q "all consumers of class ForeverConsumer2 created"

    python ./tests/integration/message_sender.py --queue con_queue_one --number 5
    python ./tests/integration/message_sender.py --queue con_queue_two --number 3

    # Make sure ForeverConsumer and ForeverConsumer2 have been initialized
    # the right number of times by counting with grep
    LOGS_SINCE=$(docker logs amqp-dispatcher_dispatcher_1 --since "$NOW_TIMESTAMP" 2>&1)

    CONSUMER_1_MESSAGES_RECEIVED=$(echo "$LOGS_SINCE" | grep -c "ForeverConsumer receiving message")
    CONSUMER_2_MESSAGES_RECEIVED=$(echo "$LOGS_SINCE" | grep -c "ForeverConsumer2 receiving message")

    # These are the consumer counts
    assert_equal "$CONSUMER_1_MESSAGES_RECEIVED" 3
    assert_equal "$CONSUMER_2_MESSAGES_RECEIVED" 2

    run docker exec amqp-dispatcher_rabbit_1 rabbitmqctl list_queues --quiet --formatter csv
    QUEUES=$output
    assert_equal "${#lines[@]}" 3

    # Messages have not been acknowledged, so they stay on the queue.
    run clean_and_sort_csv "$QUEUES"
    assert_line --index 0 "name,messages"
    assert_line --index 1 "con_queue_one,5"
    assert_line --index 2 "con_queue_two,3"
}

teardown() {
    teardown_sequence
}

# disconnection test
# test that when n messages are being consumed, and there is a
# disconnection, n messages are still queued after the reconnection
# happens