import logging;
import from logging { Logger }
import from jivas.agent.core.agent { Agent }
import from jivas.agent.memory.memory { Memory }
import from jivas.agent.memory.frame { Frame }
import from jivas.agent.memory.advance { Advance }
import from jivas.agent.memory.interaction { Interaction }
import from jivas.agent.action.agent_graph_walker { agent_graph_walker }


walker test_interactions(agent_graph_walker) {

    has session_id:str = "";
    has max_interactions:int = 5;
    has response:list = [];

    # set up logger
    static has logger:Logger = logging.getLogger(__name__);

    can on_agent with Agent entry {
        visit [-->](`?Memory);
    }

    can on_memory with Memory entry {
        if(self.session_id) {
            visit [-->](`?Frame)(?session_id == self.session_id);
        } else {
            visit [-->](`?Frame);
        }
    }

    can on_frame with Frame entry {
        visit [->:Advance:->](`?Interaction);
    }

    can on_interaction with Interaction entry {
        if "ModelActionResult" in here.data {
            self.response.append({
                "utterance": here.utterance,
                "ModelActionResult": here.data["ModelActionResult"]
            });
        }
        visit [->:Advance:->](`?Interaction);
    }

    can on_exit with exit {
        self.response.reverse();
        self.response = self.response[:self.max_interactions];
    }

}

