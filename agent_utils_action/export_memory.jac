import:py logging;
import:py traceback;
import:py from logging { Logger }
import:py base64;
import:jac from jivas.agent.core.agent { Agent }
import:jac from jivas.agent.action.action { Action }
import:jac from jivas.agent.action.actions { Actions }
import:jac from jivas.agent.action.interact_graph_walker { interact_graph_walker }


walker export_memory :interact_graph_walker: {

    has status:int = 200;
    has response:dict = {};
    has session_id:str = "";
    has frame_data:dict = {}; # dict with id of frame as key mapping to all interactions on that frame
    has save_to_file:bool = False;
    has json:bool = False;

    # set up logger
    static has logger:Logger = logging.getLogger(__name__);

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
        self.frame_data = here.export_memory(agent_id=self.agent_id, session_id=self.session_id, json=self.json, save_to_file=self.save_to_file);

        # update response
        self.response = self.frame_data;

    }

}