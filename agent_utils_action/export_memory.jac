import:py logging;
import:py traceback;
import:py from logging { Logger }
import:py base64;
import:jac from jivas.agent.core.agent { Agent }
import:jac from jivas.agent.action.action { Action }
import:jac from jivas.agent.action.actions { Actions }
import:jac from jivas.agent.action.interact_graph_walker { interact_graph_walker }


walker export_memory :interact_graph_walker: {

    has session_id:str = "";
    has response:dict = {};

    # set up logger
    static has logger:Logger = logging.getLogger(__name__);

    can on_agent with Agent entry {
        visit [-->](`?Actions);
    }

    can on_actions with Actions entry {
        visit [-->](`?Action)(?enabled==True)(?label=='AgentUtilsAction');
    }

    can on_action with Action entry {
        # retrieve memory
        self.response = here.get_agent().get_memory().export_memory(self.session_id);
    }

}