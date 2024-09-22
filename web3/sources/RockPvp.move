module 0x4b18ae161b7534f009ea5b2a16f61735e7d82142f2db1ebd35f7f494c3d4bcb7::RockPaperScissors {
    use std::signer;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_std::randomness;
    use aptos_framework::timestamp;

    // Define moves for rock-paper-scissors
    const ROCK: u8 = 0;
    const PAPER: u8 = 1;
    const SCISSORS: u8 = 2;

    // Error codes
    const EINVALID_MOVE: u64 = 1;
    const EGAME_ALREADY_EXISTS: u64 = 2;
    const EGAME_NOT_FOUND: u64 = 3;
    const EINVALID_BET: u64 = 4;

    // Struct to hold game state
    struct Game has key {
        player: address,
        bet_amount: u64,
        player_move: u8,
        robot_move: u8,
        result: u8, // 0: Tie, 1: Player wins, 2: Robot wins
        player_reward: Coin<AptosCoin>, // Store the reward here
    }

    // Function to start the game and place a bet
    #[lint::allow_unsafe_randomness]

    public entry fun start_game(player: &signer, bet_amount: u64, player_move: u8) {
        let player_address = signer::address_of(player);
        
        // Ensure the move is valid
        assert!(player_move <= SCISSORS, EINVALID_MOVE);
        
        // Ensure the player doesn't already have an active game
        assert!(!exists<Game>(player_address), EGAME_ALREADY_EXISTS);

        // Ensure the bet amount is valid
        assert!(bet_amount > 0, EINVALID_BET);

        // Withdraw the bet amount from the player
        let bet = coin::withdraw<AptosCoin>(player, bet_amount);

        // Generate robot's move
        let robot_move = generate_robot_move();

        // Resolve the game
        let result = resolve_winner(player_move, robot_move);

        // Handle the result
        let player_reward = if (result == 1) {
            // Player wins, double their bet
            coin::extract(&mut bet, bet_amount)
        } else if (result == 2) {
            // Robot wins, player loses bet
            coin::zero<AptosCoin>()
        } else {
            // Tie, return the bet
            coin::extract(&mut bet, bet_amount)
        };

        // Create and store the game result
        let game = Game {
            player: player_address,
            bet_amount,
            player_move,
            robot_move,
            result,
            player_reward,
        };
        move_to(player, game);

        // Destroy any remaining coins (should be zero in all cases now)
        coin::destroy_zero(bet);
    }

    // Function to generate the robot's move
    fun generate_robot_move(): u8 {
        let seed = timestamp::now_microseconds();
        let random_number = randomness::u64_range(seed, 3);
        (random_number as u8)
    }

    // Function to resolve the winner
    fun resolve_winner(player_move: u8, robot_move: u8): u8 {
        if (player_move == robot_move) {
            0 // Tie
        } else if (
            (player_move == ROCK && robot_move == SCISSORS) ||
            (player_move == PAPER && robot_move == ROCK) ||
            (player_move == SCISSORS && robot_move == PAPER)
        ) {
            1 // Player wins
        } else {
            2 // Robot wins
        }
    }

    // Function to claim reward
    public entry fun claim_reward(player: &signer) acquires Game {
        let player_address = signer::address_of(player);
        assert!(exists<Game>(player_address), EGAME_NOT_FOUND);
        
        let Game { player: _, bet_amount: _, player_move: _, robot_move: _, result: _, player_reward } = 
            move_from<Game>(player_address);
        
        // Deposit the reward to the player's account
        coin::deposit(player_address, player_reward);
    }

    // Function to clean up the game state
    public entry fun clean_up_game(player: &signer) acquires Game {
        let player_address = signer::address_of(player);
        assert!(exists<Game>(player_address), EGAME_NOT_FOUND);
        let Game { 
            player: _, 
            bet_amount: _, 
            player_move: _, 
            robot_move: _, 
            result: _,
            player_reward
        } = move_from<Game>(player_address);
        
        // Destroy any unclaimed rewards
        coin::destroy_zero(player_reward);
    }
}