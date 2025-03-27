import:py json;
import:py yaml;
import:py logging;
import:py traceback;
import:py base64;
import:py from logging { Logger }
import:py from jivas.agent.modules.agentlib.utils { Utils }
import:jac from jivas.agent.core.agent { Agent }
import:jac from jivas.agent.core.import_agent { import_agent }
import:jac from jivas.agent.action.action { Action }
import:jac from jivas.agent.action.actions { Actions }
import:jac from jivas.agent.action.interact_graph_walker { interact_graph_walker }


walker import_agent_utils :interact_graph_walker: {

    has response:bool = False;
    has daf_descriptor:dict = {};
    has daf_knowledge:list = [];
    has daf_memory:list = [];
    has knode_embeddings:bool = False;


    # set up logger
    static has logger:Logger = logging.getLogger(__name__);

    can on_agent with Agent entry {
        # import descriptor
        try{

            if(self.daf_descriptor){
                # self spawn import_agent(descriptor = self.daf_descriptor, reporting = False);
                self.import_from_descriptor(here, self.daf_descriptor);
            }

            # import memory
            if(self.daf_memory){
                if( agent_utils_action := here.get_actions().get(action_label='AgentUtilsAction')){
                    agent_utils_action.import_memory(data=self.daf_memory, overwrite=False);
                }
            }

            # import knowledge
            if(self.daf_knowledge){
                if( typesense_vector_store_action := here.get_actions().get(action_label='TypesenseVectorStoreAction')){

                    if(self.knode_embeddings and "vec" in self.daf_knowledge){
                        self.response = typesense_vector_store_action.add_embeddings(self.daf_knowledge);
                    }else{
                        self.response = typesense_vector_store_action.import_knodes(self.daf_knowledge);
                    }
                }
            }
            self.response = True;
        } except Exception as e {
            self.logger.error(f"an exception occurred, {traceback.format_exc()}");
        }
    }

    can import_from_descriptor(agents_node:Agents, descriptor:str) -> Agent {
        # imports an agent from an agent descriptor
        agent_data = {};
        agent_node = None;

        if(not descriptor) {
            return None;
        }

        # TODO: build an agent data validator and execute at this point

        # Try to parse the content as JSON
        if(isinstance(descriptor, str)) {
            try {
                agent_data = json.loads(descriptor);
            } except json.JSONDecodeError {}

            # Try to parse the content as YAML
            try {
                agent_data = yaml.safe_load(descriptor);
            } except yaml.YAMLError {}

        }else{
            agent_data = descriptor;
        }

        if(not agent_data) {
            self.logger.error('no agent data available for import');
            return None;
        }

        # Update agent node if exists or create new
        if (agent_data.get('id', None)) {

            try {
                agent_node = &agent_data["id"];
            } except Exception as e {
                self.logger.error(f"an exception occurred, {traceback.format_exc()}");
                return None;
            }

        }
        else {
            agent_name = agent_data.get('name');
            # if agent has same name as existing agent, update
            if(_node := agents_node.get_by_name(agent_name)) {
                agent_node = _node;
            } else {
                # otherwise we create a new agent
                if( agent_node := Agent(
                    name=agent_name,
                    description=agent_data.get('description', '')
                )) {
                    # attach the agent node if new and unattached
                    if(not agents_node.get_by_id(agent_node.id)) {
                        agents_node ++> agent_node;
                    }
                    self.logger.info(f"agent created: {agent_node.name}");
                } else {
                    self.logger.error(f"unable to create agent: {agent_name}");
                }
            }
        }

        if(agent_node) {
            # retrieves existing descriptor root folder or creates it
            descriptor_root = Utils.get_descriptor_root();
            # map to agent descriptor
            agent_node.descriptor = f"{descriptor_root}/{agent_node.id}.yaml";

            # Attach memory and actions node if not exists
            agent_node.get_memory();
            agent_node.get_actions();

            # import requires that agent re-install all actions
            if(agent_node := agent_node.update(
                data=agent_data,
                with_actions=True
            )) {
                # write out descriptor
                agent_node.export_descriptor();
                return agent_node;
            }

        }

        return None;
    }
}