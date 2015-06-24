class BracketsController < ApplicationController
  before_action :authenticate_user!

  load_and_authorize_resource :pool, only: [:index, :create]
  load_and_authorize_resource :bracket, through: :pool, only: [:create]
  load_and_authorize_resource :bracket, except: [:index, :create]

  before_action :load_pool, except: [:index, :create]

  def index
    if @pool.started?
      @brackets = @pool.brackets.includes(:bracket_point).joins(:bracket_point).order("best_possible asc", "points desc", "possible_points desc")
      set_jskit_index_payload
    else
      @brackets = @pool.brackets.where(user_id: current_user).to_a
      @brackets.sort_by! { |x| [[:ok, :unpaid, :incomplete].index(x.status), x.name] }
      @unpaid_brackets = @brackets.select(&:unpaid?)
    end
  end

  def show
    set_jskit_show_payload
  end

  def edit
    set_jskit_edit_payload
  end

  def create
    @bracket.pool = @pool

    if @bracket.save
      redirect_to edit_bracket_path(@bracket)
    else
      redirect_to pool_brackets_path(@pool), alert: "Problem creating a new bracket. Please try again."
    end
  end

  def update
    if @bracket.update(update_params)
      redirect_to pool_brackets_path(@pool), notice: "Bracket Saved"
    else
      flash.now[:error] = "Problem saving bracket. Please try again"
      render :edit
    end
  end

  def destroy
    @bracket.destroy
    redirect_to pool_brackets_path(@pool), notice: "Bracket Destroyed"
  end

  private

  def load_pool
    @pool = @bracket.pool
  end

  def update_params
    params.require(:bracket).permit(:tie_breaker, :name, :points, :possible_points)
  end

  def set_jskit_index_payload
    set_action_payload(current_user.brackets.where(pool_id: @pool.id).pluck(:id))
  end

  def set_jskit_show_payload
    max_updated_at = @bracket.tournament.games.maximum(:updated_at).to_i
    teams_cache_key = "tournament-#{@bracket.tournament.id}/eliminated/all-#{max_updated_at}"
    games_cache_key = "tournament-#{@bracket.tournament.id}/games-played/all-#{max_updated_at}"

    eliminated_team_ids = Rails.cache.fetch(teams_cache_key) do
      @bracket.tournament.teams.to_a.select(&:eliminated?).map(&:id)
    end

    games_played_slots = Rails.cache.fetch(games_cache_key) do
      @bracket.tournament.games.already_played.map do |game|
        [game.next_game.try(:id), game.next_slot, game.winner.id]
      end
    end

    set_action_payload(eliminated_team_ids, games_played_slots)
  end

  def set_jskit_edit_payload
    games = @bracket.picks.each_with_object({}) do |pick, obj|
      game = pick.game
      choice = pick.choice < 0 ? nil : pick.choice

      obj[game.id] = {
          id: game.id,
          teamOne: team_hash(game.team_one),
          teamTwo: team_hash(game.team_two),
          gameOneId: game.game_one_id,
          gameTwoId: game.game_two_id,
          nextGameId: game.next_game.try(:id),
          nextSlot: game.next_slot,
          pickId: pick.id,
          choice: choice
      }
    end

    set_action_payload(games)
  end

  def team_hash(team)
    team.present? ? { id: team.id, seed: team.seed, name: team.name } : nil
  end
end
