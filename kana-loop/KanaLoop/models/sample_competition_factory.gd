class_name SampleCompetitionFactory
extends RefCounted

static func create_sample_competition() -> Dictionary:
	var ruleset := Ruleset.new("ruleset_standard", "Standard Rules")
	ruleset.scoring_rules = {"goal": 1}

	var competition := Competition.new("competition_sample", "Sample Competition")
	competition.ruleset_id = ruleset.id

	var home_team := Team.new("team_red", competition.id, "Red Team")
	home_team.short_name = "RED"
	var away_team := Team.new("team_blue", competition.id, "Blue Team")
	away_team.short_name = "BLU"

	var players: Array[Player] = [
		Player.new("player_red_1", home_team.id, "Red Player One"),
		Player.new("player_red_2", home_team.id, "Red Player Two"),
		Player.new("player_blue_1", away_team.id, "Blue Player One"),
		Player.new("player_blue_2", away_team.id, "Blue Player Two"),
	]

	for player in players:
		competition.add_player_id(player.id)
		if player.team_id == home_team.id:
			home_team.add_player_id(player.id)
		elif player.team_id == away_team.id:
			away_team.add_player_id(player.id)

	competition.add_team_id(home_team.id)
	competition.add_team_id(away_team.id)

	var game := Game.new("game_sample_1", competition.id)
	game.ruleset_id = ruleset.id
	game.home_team_id = home_team.id
	game.away_team_id = away_team.id
	game.scheduled_at = int(Time.get_unix_time_from_system()) + 86400
	competition.add_game_id(game.id)

	return {
		"competition": competition,
		"ruleset": ruleset,
		"teams": [home_team, away_team],
		"players": players,
		"games": [game],
	}

static func create_serialized_sample_competition() -> Dictionary:
	var sample := create_sample_competition()
	var serialized_teams: Array[Dictionary] = []
	var serialized_players: Array[Dictionary] = []
	var serialized_games: Array[Dictionary] = []
	for team in sample["teams"]:
		serialized_teams.append(team.to_dict())
	for player in sample["players"]:
		serialized_players.append(player.to_dict())
	for game in sample["games"]:
		serialized_games.append(game.to_dict())
	return {
		"competition": sample["competition"].to_dict(),
		"ruleset": sample["ruleset"].to_dict(),
		"teams": serialized_teams,
		"players": serialized_players,
		"games": serialized_games,
	}
