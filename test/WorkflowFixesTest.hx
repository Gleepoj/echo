import echoes.Entity;
import echoes.Workflow;

using buddy.Should;

/** Regression tests for the fork changes (fixed/post system lists, stale entities) **/
class WorkflowFixesTest extends buddy.BuddySuite {
    public function new() {
        describe("Test post systems", {
            var s:CountingSystem;

            beforeEach({
                Workflow.reset();
                s = new CountingSystem();
            });

            it("should be updated once per postUpdate, even if added twice", {
                Workflow.addPostSystem(s);
                Workflow.addPostSystem(s);
                Workflow.postUpdate(0);
                Workflow.postSystems.length.should.be(1);
                s.count.should.be(1);
            });

            it("should not be added to both lists", {
                Workflow.addPostSystem(s);
                Workflow.addFixedSystem(s);
                Workflow.fixedUpdate(0);
                Workflow.postUpdate(0);
                Workflow.fixedSystems.length.should.be(0);
                s.count.should.be(1);
            });

            it("should be updated by postUpdate only", {
                Workflow.addPostSystem(s);
                Workflow.fixedUpdate(0);
                s.count.should.be(0);
                Workflow.postUpdate(0);
                s.count.should.be(1);
            });

            it("should be found by hasSystem and hasPostSystem only", {
                Workflow.addPostSystem(s);
                Workflow.hasSystem(s).should.be(true);
                Workflow.hasPostSystem(s).should.be(true);
                Workflow.hasFixedSystem(s).should.be(false);
            });

            it("should be removed by removeSystem", {
                Workflow.addPostSystem(s);
                Workflow.removeSystem(s);
                Workflow.hasSystem(s).should.be(false);
                s.isActive().should.be(false);
                Workflow.postUpdate(0);
                s.count.should.be(0);
            });

            it("should be removed by reset", {
                Workflow.addPostSystem(s);
                Workflow.reset();
                Workflow.postSystems.length.should.be(0);
                s.isActive().should.be(false);
            });
        });

        describe("Test stale entities", {
            beforeEach({
                Workflow.reset();
            });

            it("INVALID should not be valid", {
                Entity.INVALID.isValid().should.be(false);
            });

            it("an entity created before reset should not be valid", {
                var old = new Entity();
                old.add(new FixComponent());
                Workflow.reset();
                old.isValid().should.be(false);
            });

            it("destroying an entity from before reset should not hand out its id twice", {
                new Entity();
                var old = new Entity(); // id 1
                Workflow.reset();
                var fresh = new Entity(); // id 0, next id is 1
                old.destroy(); // must be a no-op, not push id 1 to the pool
                var a = new Entity();
                var b = new Entity();
                (a:Int).should.not.be((b:Int));
                fresh.isValid().should.be(true);
            });
        });
    }
}

class CountingSystem extends echoes.System {
    public var count = 0;
    @u function tick() count++;
}

class FixComponent {
    public function new() {}
}
