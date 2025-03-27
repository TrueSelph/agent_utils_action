import:py json;
import:py yaml;
import:py schedule;
import:py logging;
import:py traceback;
import:py from logging { Logger }
import:jac from jivas.agent.action.action { Action }

node AgentUtilsAction :Action: {
    # Provides controls to provide power user controls for the management of agents.

    # set up logger
    static has logger:Logger = logging.getLogger(__name__);

    can purge_memory(session_id:str) {
        if(result := self.get_agent().get_memory().purge(session_id)) {
            return True;
        } else {
            return False;
        }
    }

    can refresh_memory(session_id:str) {
        return self.get_agent().get_memory().refresh(session_id);
    }

    can import_memory(data:str, overwrite:bool) {
        # accepts a string-based representation
        memory_data = {};
        if isinstance(data, str) {
            importing_error_message = "";

            # Try to parse the content as JSON
            try {
                memory_data = json.loads(data);
            } except json.JSONDecodeError {}

            # Try to parse the content as YAML
            try {
                memory_data = yaml.safe_load(data);
            } except yaml.YAMLError {}

        }else{
            memory_data = data;
        }

        return self.get_agent().get_memory().import_memory(memory_data, overwrite);
    }

    can export_memory(agent_id:str, session_id:str, json:bool, save_to_file:bool=False) {
        # returns a structured memory dump
        return self.get_agent().get_memory().export_memory(agent_id, session_id, json, save_to_file);

    }

    can memory_healthcheck(agent_id:str, session_id:str = "", verbose:bool=False) {
        # returns details about the agent memory
        return self.get_agent().get_memory().memory_healthcheck(agent_id, session_id, verbose);
    }

    can set_logging(logging:bool) {
        self.get_agent().set_logging(logging);
        return True;
    }

    can get_logging() {
        return self.get_agent().is_logging();
    }

}