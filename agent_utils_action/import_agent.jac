import logging;
import from logging { Logger }
import from jivas.agent.core.agent { Agent }
import from jivas.agent.action.action { Action }
import from jivas.agent.action.actions { Actions }
import from jivas.agent.modules.data.serialization { LongStringDumper }
import from jivas.agent.action.agent_graph_walker { agent_graph_walker }
import from jivas.agent.modules.action.path { action_walker_path }
import from jivas.agent.core.agent { Agent }


walker import_agent(agent_graph_walker) {
    # accepts agent_id and returns dict of exported agent descriptor

    has data:str = "";
    has purge:bool = True;
    has response:dict = {};
    has reporting:bool = True;

    static has logger:Logger = logging.getLogger(__name__);


    class __specs__ {
        static has private: bool = False;
        static has path: str = action_walker_path(__module__);
    }

    can on_agent with Agent entry {
        visit [-->](`?Actions);
    }

    can on_actions with Actions entry {
        visit [-->](`?Action)(?enabled==True)(?label=='AgentUtilsAction');
    }

    can on_action with Action entry {
        self.logger.info(f"Importing data: {self.data}");
        self.logger.info(f"Importing data: {type(self.data)}");
        self.response = here.import_daf(self.data, self.purge);
        if self.reporting {
            report self.response;
        }
    }
}
