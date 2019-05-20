package;

import ur.Game;

using tink.CoreApi;

@:asserts
class Gameplay {
    var game: Game;

    @:before
    public function setup() {
        game = new Game({
            TokenCount: 7,
            DiceCount: 4,

            board: [
                Star,	Normal, Normal, Normal,	Normal/*S2*/,	Normal/*E2*/, Star,   Normal,
                Normal,	Normal, Normal, Star,	Normal,			Normal,       Normal, Normal,
                Star,	Normal, Normal, Normal,	Normal/*S1*/,	Normal/*E1*/, Star,   Normal,
            ],

            player1: new Player({ id: 1 }),
            player2: new Player({ id: 2 }),

			path1: [20, 19, 18, 17, 16, 8, 9, 10, 11, 12, 13, 14, 6, 7, 15, 23, 22, 21],
			path2: [4, 3, 2, 1, 0, 8, 9, 10, 11, 12, 13, 14, 22, 23, 15, 7, 6, 5],
        });

        return Noise;
    }

    public function initialValues() {
		asserts.assert(game.TokenCount == 7);
		asserts.assert(game.DiceCount == 4);
        return asserts.done();
    }

    public function initialPlayer() {
        asserts.assert(game.currentPlayer == 1);
		return asserts.done();
    }

    public function rollBeforeMove() {
        game.skipMoveToken().handle(o -> asserts.assert(!o.isSuccess())); // TODO (DK) match 'invalid phase'
        game.moveToken(1).handle(o -> asserts.assert(!o.isSuccess())); // TODO (DK) match 'invalid phase'
        game.rollDice().handle(o -> asserts.assert(o.isSuccess()));
        return asserts.done();
    }

    public function moveAfterRoll() {
        game.rollDice().handle(o -> asserts.assert(o.isSuccess()));
        game.moveToken(0).handle(o -> asserts.assert(!o.isSuccess())); // TODO (DK) match 'invalid phase'?
		return asserts.done();
	}

    public function checkPathBounds() {
        game.rollDice().handle(o -> asserts.assert(o.isSuccess()));
        game.moveToken(8 * 3).handle(o -> asserts.assert(!o.isSuccess())); // TODO (DK) match 'overshoot end'?
        game.moveToken(-1).handle(o -> asserts.assert(!o.isSuccess())); // TODO (DK) match 'index out of bounds'?

		return asserts.done();
	}

    public function new() {}
}
