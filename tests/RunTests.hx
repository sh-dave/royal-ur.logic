package;

import tink.unit.*;
import tink.testrunner.*;

class RunTests {
	public static function main() {
		Runner.run(TestBatch.make([
			new Gameplay(),
		])).handle(Runner.exit);
	}
}
