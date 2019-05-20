package ur;

import coconut.data.*;
import tink.pure.*;

using Lambda;
using tink.CoreApi;

enum FieldType {
	Normal;
	Star;
}

enum Phase {
    RollDicePhase;
    MoveTokenPhase;
}

class Player implements Model {
    @:constant var id: Int;
}

typedef G = {
    final tok1: List<Int>;
    final tok2: List<Int>;
    final dice: List<Int>;
}

enum Action {
    DiceRoll( g: G, player: Int );
    TokenMove( g: G, player: Int, pos: Int, nextPlayer: Bool );
    SkippedTokenMove( g: G, player: Int );
}

enum State {
    InProgress( g: G, phase: Phase );
    Won( g: G, winner: Int );
}

typedef MoveOutcome = {
    final tok1: List<Int>;
    final tok2: List<Int>;
    final nextPlayer: Bool;
}

class Game implements Model {
    @:external var Opt_JumpOverStarTokens: Bool = @byDefault false;

    @:constant var TokenCount: Int;
    @:constant var DiceCount: Int;
    @:constant var PlayerCount: Int = 2;

    @:constant var player1: Player;
    @:constant var player2: Player;

    @:constant var board: List<FieldType>;
    @:constant var path1: List<Int>;
    @:constant var path2: List<Int>;

    @:observable var actions: List<Action> = [];

    @:computed var currentPlayer: Int = {
        return switch actions.first() {
            case None: 1;
            case Some(v):
                switch v {
                    case DiceRoll(_, player):
                        player;
                    case TokenMove(_, player, _, nextPlayer):
                        nextPlayer ? nextPlayerId(player) : player;
                    case SkippedTokenMove(_, player):
                        nextPlayerId(player);
                }
        }
    }

    @:computed var state: State = {
        switch actions.first() {
            case None:
                return InProgress({
                    tok1: [for (i in 0...TokenCount) 20],
                    tok2: [for (i in 0...TokenCount) 4],
                    dice: [for (i in 0...DiceCount) -1],
                }, RollDicePhase);
            case Some(s):
                switch s {
                    case DiceRoll(g, _):
                        return InProgress(g, MoveTokenPhase);
                    case TokenMove(g, _, _, _):
                        if (g.tok1.count(f -> f == 21) == g.tok1.length) {
                            return Won(g, 1);
                        }

                        if (g.tok2.count(f -> f == 5) == g.tok2.length) {
                            return Won(g, 2);
                        }

                        return InProgress(g, RollDicePhase);
                    case SkippedTokenMove(g, _):
                        return InProgress(g, RollDicePhase);
                }
        }
    }

    @:transition
    function rollDice() {
        return switch state {
            case InProgress(g, RollDicePhase):
                {
                    actions: actions.prepend(DiceRoll({
                        tok1: g.tok1,
                        tok2: g.tok2,
                        dice: [for (i in 0...DiceCount) rollDie()],
                    }, currentPlayer))
                }
            case _:
                Failure(new Error('invalid phase'));
        }
    }

    function rollDie()
        return Std.random(2); // TODO (DK) use proper random class

    @:transition
    function moveToken( pos: Int ) {
        return switch state {
            case InProgress(g, MoveTokenPhase):
                final steps = g.dice.toArray().fold((v, i) -> v + i, 0);
                final result = moveTokenImpl(g, currentPlayer, pos, steps);

                switch result {
                    case Success(data):
                        {
                            actions: actions.prepend(TokenMove(
                                { tok1: data.tok1, tok2: data.tok2, dice: g.dice },
                                currentPlayer,
                                pos,
                                data.nextPlayer)
                            )
                        }
                    case Failure(err):
                        Failure(new Error(err));
                }
            case _:
                Failure(new Error('invalid phase'));
        }
    }

    @:transition
    function skipMoveToken() {
        return switch state {
            case InProgress(g, MoveTokenPhase): // TODO (DK) only allow when dice == 0 or all moves are blocked
                {
                    actions: actions.prepend(SkippedTokenMove(g, currentPlayer)),
                }
            case _:
                return Failure(new Error('invalid phase'));
        }
    }

    public function hasValidMoves( g: G, player: Int, steps: Int ) : Bool {
        var tokens = (player == 1 ? g.tok1 : g.tok2).toArray();
        var moves = 0;

        for (i in 0...8 * 3) {
            moves += switch moveTokenImpl(g, player, i, steps) {
                case Success(_): 1;
                case Failure(_): 0;
            }
        }

        return moves != 0;
    }

    @:transition
    function reset() {
        return { actions: null }
    }

    function nextPlayerId( id )
        return 1 + (((id - 1) + 1) % PlayerCount);

    function moveTokenImpl( g: G, player: Int, pos: Int, steps: Int ) : Outcome<MoveOutcome, String> {
		final tokens = (player == 1 ? g.tok1 : g.tok2).toArray();
		final tokenIndex = tokens.indexOf(pos);

        if (tokenIndex < 0) {
            return Failure('no token on position `$pos`');
        }

		// move it along the path
		final otherPlayer = nextPlayerId(player);
		final oppTokens = (otherPlayer == 1 ? g.tok1 : g.tok2).toArray();
		final path = (player == 1 ? path1 : path2).toArray();
		final currentPathIndex = path.indexOf(tokens[tokenIndex]);
		final targetPathIndex = currentPathIndex + steps;
		final targetFieldIndex = path[targetPathIndex];

		// token would move out of path bounds
		if (targetPathIndex >= path.length) {
			return Failure('overshoot end');
		}

        final ourSpot = tokens.indexOf(targetFieldIndex) != -1;

        // token would move on top of one of our own
        if (ourSpot) {
            // multiple tokens can move off the board (last index in path)
            if (targetFieldIndex == path[path.length - 1]) {
                tokens[tokenIndex] = targetFieldIndex;

                return Success({
                    tok1: player == 1 ? tokens : oppTokens,
                    tok2: player == 1 ? oppTokens : tokens,
                    nextPlayer: true,
                });
            } else {
                return Failure('can not move to occupied field');
            }
        }

        // token would move on top of opponents token
        final oppSpot = oppTokens.indexOf(targetFieldIndex) != -1;

        if (oppSpot) {
            final targetField = board.toArray()[targetFieldIndex];

            switch targetField {
                case Star:
                    if (Opt_JumpOverStarTokens) {
                        return moveTokenImpl(g, player, pos, steps + 1);
                    } else {
                        return Failure('can not kick opponent from star field');
                    }
                case Normal:
                    // move our token to the new field
                    tokens[tokenIndex] = targetFieldIndex;

                    // kick opponents token back to start
                    for (i in 0...oppTokens.length) {
                        if (oppTokens[i] == targetFieldIndex) {
                            final otherPath = (otherPlayer == 1 ? path1 : path2).toArray();
                            oppTokens[i] = otherPath[0];
                        }
                    }

                    return Success({
                        tok1: player == 1 ? tokens : oppTokens,
                        tok2: player == 1 ? oppTokens : tokens,
                        nextPlayer: true,
                    });
            }
        }

        // move our token to the new field
        tokens[tokenIndex] = targetFieldIndex;

        // in case we landed on a star, we can take another turn (dice roll and movement)
        final movedToStar = switch board.get(targetFieldIndex) {
            case Some(Star): true;
            case _: false;
        }

        return Success({
            tok1: player == 1 ? tokens : oppTokens,
            tok2: player == 1 ? oppTokens : tokens,
            nextPlayer: !movedToStar,
        });
    }
}
