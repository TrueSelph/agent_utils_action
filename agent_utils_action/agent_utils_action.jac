import json;
import re;
import yaml;
import logging;
import traceback;
import from logging { Logger }
import from jivas.agent.core.agent { Agent }
import from jivas.agent.action.action { Action }
import from jivas.agent.action.actions { Actions }
import from jivas.agent.memory.memory { Memory }
import from jivas.agent.memory.collection { Collection }
import from jivas.agent.core.graph_node { GraphNode }
import from jivas.agent.core.import_agent { import_agent }
import from jac_cloud.plugin.jaseci { JacPlugin as Jac }
import from jac_cloud.core.archetype { NodeAnchor }


node AgentUtilsAction(Action) {
    # Provides controls to provide power user controls for the management of agents.

    # set up logger
    static has logger:Logger = logging.getLogger(__name__);

    def purge_frame_memory(session_id:str) {
        if(result := self.get_agent().get_memory().purge_frame_memory(session_id)) {
            return True;
        } else {
            return False;
        }
    }

    def purge_collection_memory(collection_name:str) {
        # uncomment after merging jivas 2.1.21
        # if collection_name {
        #     result = (self.get_agent().get_memory() spawn _purge_collection(collection_name=collection_name)).removed;
        # }

        # remove this after merging jivas 2.1.21
        try {
            if(result := self.get_agent().get_memory().purge_collection_memory(collection_name)) {
                return True;
            }
            return False;
        } except Exception as e {
            self.logger.warning(f"Unable to purge collection: {e}");
            return False;
        }
    }

    def import_memory(data:str, overwrite:bool) {
        # imports a string-based representation of memory in YAML of JSON

        memory_data = {};

        if isinstance(data, str) {
            # Try to parse the content as JSON
            try {
                memory_data = json.loads(data);
            } except json.JSONDecodeError {
                self.logger.warning(f"Unable to parse JSON data: {data}");
            }

            # Try to parse the content as YAML
            try {
                memory_data = yaml.safe_load(data);
            } except yaml.YAMLError {
                self.logger.warning(f"Unable to parse YAML data: {data}");
            }

        } else {
            memory_data = data;
        }

        agent_node = self.get_agent();
        result = (agent_node spawn _import_memory(collections=memory_data["collections"], purge_collections=overwrite)).response;

        return self.get_agent().get_memory().import_memory({"memory": memory_data["frames"]}, overwrite);
    }

    def test_llm_call(llm_prompt_message:str="", model_name:str="", model_temperature:float=0.4, model_max_tokens:int=4096) {
        model_action := self.get_agent().get_action(action_label="LangChainModelAction");

        if not model_action {
            return {};
        }

        model_action_result = model_action.test_invoke(
            llm_prompt_message = llm_prompt_message,
            model_name=model_name,
            model_temperature=model_temperature,
            model_max_tokens=model_max_tokens,
            prompt_messages=[],
            prompt_variables={}
        );

        return model_action_result;
    }

    def export_memory(session_id:str="", export_collections:bool=True) -> dict {
        agent_node = self.get_agent();
        return (agent_node spawn _export_memory(session_id=session_id, export_collections=export_collections)).response;
    }

    def import_daf(data:str="", purge:bool=True) -> dict {
        daf_data = {};

        if isinstance(data, str) {
            # Try to parse the content as JSON
            try {
                daf_data = json.loads(data);
            } except json.JSONDecodeError {}

            # Try to parse the content as YAML
            try {
                daf_data = yaml.safe_load(data);
            } except yaml.YAMLError {}

        } else {
            daf_data = data;
        }

        root spawn import_agent(daf_data);

        if "memory" in daf_data and daf_data["memory"] {
            self.import_memory(data=daf_data["memory"], overwrite=purge);
        }

        if "knowledge" in daf_data and daf_data["knowledge"] {
            action_node = self.get_agent().get_action(action_label="TypesenseVectorStoreAction");
            if purge {
                action_node.delete_collection();
            }
            action_node.import_knodes(daf_data["knowledge"], with_embeddings=True);
        }
    }

}

# remove this after merging jivas 2.1.21
walker _purge_collection {
    # walker which carries out the traversal and purging of this collection and any related child nodes

    has removed:list = [];
    has collection_name:str = "";

    obj __specs__ {
        # make this a private walker
        static has private: bool = True;
    }

    can on_memory with Memory entry {
        if(self.collection_name) {
            visit [-->](`?Collection)(?name == self.collection_name) else {
                disengage;
            }
        } else {
            visit [-->](`?Collection);
        }
    }

    can on_collection with Collection entry {
        visit [-->] else {
            self.removed.append(here);
            Jac.destroy(here);
        }
    }

    can on_collection_node with GraphNode entry {
        try {
            visit [-->];
            self.removed.append(here);
            Jac.destroy(here);
        } except Exception as e {
            node_id = re.search(r'\[(.*?)\]', str(e)).group(1);
            node_name = re.search(r':([^:]+):', str(e)).group(1);
            filter_query = {"name": node_name, "archetype.id": node_id};
            if (cursor := NodeAnchor.Collection.find(filter_query)) {
                nodes = [n.archetype for n in cursor];
                for node_obj in nodes {
                    Jac.destroy(node_obj);
                }
            }
        }
    }
}



walker _export_memory {

    has session_id:str = "";
    has export_collections:bool = False;
    has response:dict = {};
    has frames:list = [];
    has collections:dict = {};
    has agent_node:Agent = None;

    obj __specs__ {
        static has private:bool = True;
    }

    can on_agent with Agent entry {
        self.agent_node = here;
        visit [-->](`?Actions);
    }

    can on_actions with Actions entry {
        visit [-->](`?Action)(?enabled==True)(?label=='AgentUtilsAction');
    }

    can on_action with Action entry {
        # retrieve memory
        memory = here.get_agent().get_memory();
        self.frames = memory.export_memory(self.session_id)["memory"];
        if self.export_collections {
            visit memory;
        }
    }

    can on_memory with Memory entry {
        visit [-->](`?Collection);
    }

    can on_collection with Collection entry {
        collection_name = here.name;
        action_node = self.agent_node.get_action(action_label=collection_name);
        result = action_node.export_collection();
        self.collections[collection_name] = result;
    }

    can on_exit with exit {
        self.response = {
            "frames": self.frames,
            "collections": self.collections
        };
    }

}


walker _import_memory {
    has purge_collections:bool = False;
    has response:bool = True;
    has collections:dict = {};
    has agent_node:Agent = None;

    obj __specs__ {
        static has private:bool = True;
    }

    can on_agent with Agent entry {
        self.agent_node = here;
        visit [-->](`?Memory);
    }

    can on_memory with Memory entry {
        for name in self.collections {
            visit [-->](`?Collection)(?name == name) else {
                collection = Collection(name=name);
                here ++> collection;
                visit collection;
            }
        }
    }

    can on_collection with Collection entry {
        try {

        } except Exception as e {
            self.logger.warning(f"Unable to import collection: {here.name} Error: {e}");
            return False;
        }
        collection_details = self.collections[here.name];

        action_node = self.agent_node.get_action(action_label=here.name);
        result = action_node.import_collection(collection_details, self.purge_collections);
    }

}