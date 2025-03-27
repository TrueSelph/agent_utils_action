import:py logging;
import:py traceback;
import:py from logging { Logger }
import:jac from jivas.agent.core.agents { Agents }
import:jac from jivas.agent.action.interact_graph_walker { interact_graph_walker }


walker delete_agent :interact_graph_walker: {

    has agent_id:str = "";
    has response:bool = False;

    # set up logger
    static has logger:Logger = logging.getLogger(__name__);

    can on_agents with Agents entry {
       self.response = here.delete(self.agent_id);
    }

}