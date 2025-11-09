class QueueTicketsController < ApplicationController
  before_action :set_queue_ticket, only: %i[ show edit update destroy ]

  # GET /queue_tickets or /queue_tickets.json
  def index
    @queue_tickets = QueueTicket.all
  end

  # GET /queue_tickets/1 or /queue_tickets/1.json
  def show
  end

  # GET /queue_tickets/new
  def new
    @queue_ticket = QueueTicket.new
  end

  # GET /queue_tickets/1/edit
  def edit
  end

  # POST /queue_tickets or /queue_tickets.json
  def create
    @queue_ticket = QueueTicket.new(queue_ticket_params)

    respond_to do |format|
      if @queue_ticket.save
        format.html { redirect_to @queue_ticket, notice: "Queue ticket was successfully created." }
        format.json { render :show, status: :created, location: @queue_ticket }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @queue_ticket.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /queue_tickets/1 or /queue_tickets/1.json
  def update
    respond_to do |format|
      if @queue_ticket.update(queue_ticket_params)
        format.html { redirect_to @queue_ticket, notice: "Queue ticket was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @queue_ticket }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @queue_ticket.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /queue_tickets/1 or /queue_tickets/1.json
  def destroy
    @queue_ticket.destroy!

    respond_to do |format|
      format.html { redirect_to queue_tickets_path, notice: "Queue ticket was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_queue_ticket
      @queue_ticket = QueueTicket.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def queue_ticket_params
      params.expect(queue_ticket: [ :booking_id, :position, :status, :issued_at ])
    end
end
