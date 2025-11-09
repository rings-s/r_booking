require "test_helper"

class QueueTicketsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @queue_ticket = queue_tickets(:one)
  end

  test "should get index" do
    get queue_tickets_url
    assert_response :success
  end

  test "should get new" do
    get new_queue_ticket_url
    assert_response :success
  end

  test "should create queue_ticket" do
    assert_difference("QueueTicket.count") do
      post queue_tickets_url, params: { queue_ticket: { booking_id: @queue_ticket.booking_id, issued_at: @queue_ticket.issued_at, position: @queue_ticket.position, status: @queue_ticket.status } }
    end

    assert_redirected_to queue_ticket_url(QueueTicket.last)
  end

  test "should show queue_ticket" do
    get queue_ticket_url(@queue_ticket)
    assert_response :success
  end

  test "should get edit" do
    get edit_queue_ticket_url(@queue_ticket)
    assert_response :success
  end

  test "should update queue_ticket" do
    patch queue_ticket_url(@queue_ticket), params: { queue_ticket: { booking_id: @queue_ticket.booking_id, issued_at: @queue_ticket.issued_at, position: @queue_ticket.position, status: @queue_ticket.status } }
    assert_redirected_to queue_ticket_url(@queue_ticket)
  end

  test "should destroy queue_ticket" do
    assert_difference("QueueTicket.count", -1) do
      delete queue_ticket_url(@queue_ticket)
    end

    assert_redirected_to queue_tickets_url
  end
end
