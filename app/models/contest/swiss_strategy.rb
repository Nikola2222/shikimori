class Contest::SwissStrategy < Contest::DoubleEliminationStrategy
  def dynamic_rounds?
    true
  end

  def with_additional_rounds?
    false
  end

  def total_rounds
    n = @contest.members.count
    a = 3
    @total_rounds ||= [Math.log(n, 2).ceil + a, n - 1].min

    # @total_rounds ||= Math.log(@contest.members.count, 2).ceil + 2
  end

  def fill_round_with_matches round
    if round.first?
      super
    else
      create_matches(
        round,
        Array.new(@contest.members.size).map { ContestMatch::UNDEFINED },
        group: round.last? ? ContestRound::F : ContestRound::W,
        date: round.prior_round.matches.last.finished_on +
          @contest.matches_interval.days
      )
    end
  end

  def advance_members round, _prior_round
    ids_by_wins = @statistics.sorted_scores

    round.matches.each do |match|
      ids = ids_by_wins.keys

      left_id = ids.shift
      right_id = (ids - @statistics.opponents_of(left_id)).first

      ids_by_wins.delete left_id

      if right_id
        ids_by_wins.delete right_id
      else
        # taking key of first key=>value pair
        right_id = ids_by_wins.shift.try(:first)
      end

      match_check_and_update match, left_id, right_id
    end
  end

  def match_check_and_update match, left_id, right_id
    if left_id.nil?
      left_id = right_id
      right_id = nil
      # left_id should never be nil.
      # Only right_id is expected to be nil, if there are odd number of contest members
    end

    match.update!(
      left_id:,
      left_type: @contest.member_klass.name,
      right_id:,
      right_type: @contest.member_klass.name
    )
  end

  def advance_loser match
  end

  def advance_winner match
  end

  def results round = nil
    @statistics.sorted_scores(round).map do |id, _scores|
      @statistics.members[id]
    end
  end
end
