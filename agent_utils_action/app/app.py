"""This module provides the Streamlit application for managing agent utilities."""

import json
import zipfile
from io import BytesIO
from typing import Any, Dict, List, Union

import streamlit as st
import yaml
from jvcli.client.lib.utils import (
    call_action_walker_exec,
    call_import_agent,
    jac_yaml_dumper,
)
from jvcli.client.lib.widgets import app_header, app_update_action
from streamlit_router import StreamlitRouter


def render(router: StreamlitRouter, agent_id: str, action_id: str, info: dict) -> None:
    """Render the Streamlit application for managing agent utilities."""
    # Add application header controls
    (model_key, module_root) = app_header(agent_id, action_id, info)

    with st.expander("Export daf", False):

        knode_embeddings = st.checkbox(
            "Knode Embeddings",
            value=False,
            key=f"{model_key}_exporting_daf_knode_embeddings",
        )
        knode_id = st.checkbox(
            "Knode ID", value=False, key=f"{model_key}_exporting_daf_knode_id"
        )
        export_json = st.checkbox(
            "Json", value=False, key=f"{model_key}_exporting_daf_json"
        )
        clean_descriptor = st.checkbox(
            "Clean Descriptor",
            value=True,
            key=f"{model_key}_exporting_daf_clean_descriptor",
        )
        remove_api_keys = st.checkbox(
            "Remove Api keys",
            value=False,
            key=f"{model_key}_exporting_daf_remove_api_keys",
        )

        if st.button("Export", key=f"{model_key}_btn_exporting_daf"):

            params = {
                "knode_embeddings": knode_embeddings,
                "export_json": export_json,
                "knode_id": knode_id,
                "clean_descriptor": clean_descriptor,
                "remove_api_keys": remove_api_keys,
            }

            if result := call_action_walker_exec(
                agent_id, module_root, "export_agent_utils", params
            ):

                if export_json:
                    # Convert each section to JSON
                    descriptor_json = json.dumps(result["descriptor"], indent=2)
                    memory_json = json.dumps(result["memory"], indent=2)
                    knowledge_json = json.dumps(result["knowledge"], indent=2)
                    info_json = json.dumps(result["info"], indent=2)

                    # Create a BytesIO stream for each file
                    descriptor_file = BytesIO(descriptor_json.encode("utf-8"))
                    memory_file = BytesIO(memory_json.encode("utf-8"))
                    knowledge_file = BytesIO(knowledge_json.encode("utf-8"))
                    info_file = BytesIO(info_json.encode("utf-8"))

                    # Zip the files
                    zip_buffer = BytesIO()
                    with zipfile.ZipFile(
                        zip_buffer, "a", zipfile.ZIP_DEFLATED, False
                    ) as zip_file:
                        zip_file.writestr("descriptor.json", descriptor_file.getvalue())
                        zip_file.writestr("memory.json", memory_file.getvalue())
                        zip_file.writestr("knowledge.json", knowledge_file.getvalue())
                        zip_file.writestr("info.json", info_file.getvalue())

                    # Make the ZIP file downloadable
                    namespace = result["info"]["package"]["name"]
                    namespace = namespace.replace("/", "_")
                    namespace = namespace.replace("-", "_")
                    namespace = namespace.replace(" ", "_")

                    st.download_button(
                        label="Download ZIP",
                        data=zip_buffer.getvalue(),
                        file_name=f"{namespace}_daf.zip",
                        mime="application/zip",
                    )

                else:
                    if isinstance(result, str):
                        result = yaml.safe_load(result)

                    # Convert each section to YAML
                    descriptor_yaml = jac_yaml_dumper(
                        result["descriptor"], sort_keys=False
                    )
                    memory_yaml = jac_yaml_dumper(
                        data=result["memory"], sort_keys=False
                    )
                    knowledge_yaml = jac_yaml_dumper(
                        data=result["knowledge"], sort_keys=False
                    )
                    info_yaml = jac_yaml_dumper(data=result["info"], sort_keys=False)

                    # Create a BytesIO stream for each file
                    descriptor_file = BytesIO(descriptor_yaml.encode("utf-8"))
                    memory_file = BytesIO(memory_yaml.encode("utf-8"))
                    knowledge_file = BytesIO(knowledge_yaml.encode("utf-8"))
                    info_file = BytesIO(info_yaml.encode("utf-8"))

                    # Zip the files
                    zip_buffer = BytesIO()
                    with zipfile.ZipFile(
                        zip_buffer, "a", zipfile.ZIP_DEFLATED, False
                    ) as zip_file:
                        zip_file.writestr("descriptor.yaml", descriptor_file.getvalue())
                        zip_file.writestr("memory.yaml", memory_file.getvalue())
                        zip_file.writestr("knowledge.yaml", knowledge_file.getvalue())
                        zip_file.writestr("info.yaml", info_file.getvalue())

                    # Ensure the stream position is at the start
                    zip_buffer.seek(0)

                    # Make the ZIP file downloadable
                    namespace = result["info"]["package"]["name"]
                    namespace = namespace.replace("/", "_")
                    namespace = namespace.replace("-", "_")
                    namespace = namespace.replace(" ", "_")

                    st.download_button(
                        label="Download ZIP",
                        data=zip_buffer.getvalue(),
                        file_name=f"{namespace}_daf.zip",
                        mime="application/zip",
                    )
            else:
                st.error("Unable to export agent")

    with st.expander("Import daf", False):
        # Initialize lists to store classified data
        descriptors = {}
        knowledge = []
        memory = []
        knode_embeddings = False

        uploaded_files = st.file_uploader(
            "Upload a file or multiple files",
            type=["json", "yaml", "yml"],
            accept_multiple_files=True,
        )

        if uploaded_files:
            for uploaded_file in uploaded_files:
                try:
                    # Determine the file type
                    if uploaded_file.type == "application/json":
                        data = json.load(uploaded_file)
                    elif uploaded_file.type in ["text/yaml", "application/x-yaml"]:
                        # Handle YAML files
                        data = yaml.safe_load(uploaded_file)
                    else:
                        st.error("Unsupported file type or error processing the file!")
                        continue

                    # Classify the loaded data
                    classification = classify_data(data)
                    if classification == "descriptor":
                        descriptors = data
                    elif classification == "knowledge":
                        knowledge = data
                    elif classification == "memory":
                        memory = data
                    else:
                        st.warning(
                            f"{uploaded_file.name} didn't match any known schema."
                        )

                except Exception as e:
                    st.error(f"Error processing {uploaded_file.name}: {str(e)}")

            if knowledge:
                knode_embeddings = st.checkbox(
                    "Knode Embeddings",
                    value=False,
                    key=f"{model_key}_importing_daf_knode_embeddings",
                )

            if st.button("Import", key=f"{model_key}_btn_importing_daf"):

                params = {
                    "knode_embeddings": knode_embeddings,
                    "daf_descriptor": descriptors,
                    "daf_knowledge": knowledge,
                    "daf_memory": memory,
                }

                if result := call_action_walker_exec(
                    agent_id, module_root, "import_agent_utils", params
                ):
                    st.success("Daf imported successfully")
                else:
                    st.error("Failed to import daf.")

    with st.expander("Logging", False):
        _logging = call_action_walker_exec(agent_id, module_root, "get_logging")
        logging = st.checkbox(
            "Log Interactions", value=_logging, key=f"{model_key}_logging"
        )

        if st.button("Update", key=f"{model_key}_btn_logging_update"):
            if result := call_action_walker_exec(
                agent_id, module_root, "set_logging", {"agent_logging": logging}
            ):
                st.success("Agent logging config updated")
            else:
                st.error(
                    "Failed to update logging config. Ensure that there is something to refresh or check functionality"
                )

    with st.expander("Refresh Memory", False):
        session_id = st.text_input(
            "Session ID", value="", key=f"{model_key}_refresh_session_id"
        )

        if st.button(
            "Purge", key=f"{model_key}_btn_refresh", disabled=(not session_id)
        ):
            # Call the function to purge
            if result := call_action_walker_exec(
                agent_id, module_root, "refresh_memory", {"session_id": session_id}
            ):
                st.success("Agent memory refreshed successfully")
            else:
                st.error(
                    "Failed to refresh agent memory. Ensure that there is something to refresh or check functionality"
                )

    with st.expander("Purge Memory", False):
        session_id = st.text_input(
            "Session ID (optional)", value="", key=f"{model_key}_purge_session_id"
        )

        if st.button("Purge", key=f"{model_key}_btn_purge"):
            # Call the function to purge
            if result := call_action_walker_exec(
                agent_id, module_root, "purge_memory", {"session_id": session_id}
            ):
                st.success("Agent memory purged successfully")
            else:
                st.error(
                    "Failed to purge agent memory. Ensure that there is something to purge or check functionality"
                )

    with st.expander("Import Agent", False):
        agent_descriptor = st.text_area(
            "Agent Descriptor in YAML/JSON",
            value="",
            height=170,
            key=f"{model_key}_agent_descriptor",
        )

        if st.button("Import", key=f"{model_key}_btn_import_agent"):
            # Call the function to import
            if result := call_import_agent(descriptor=agent_descriptor):
                st.success("Agent imported successfully")
            else:
                st.error(
                    "Failed to import agent. Ensure that the  descriptor is in valid YAML format"
                )

        uploaded_file = st.file_uploader("Upload Desciptor file")

        if uploaded_file is not None:
            st.write(uploaded_file)
            if result := call_import_agent(descriptor=uploaded_file):
                st.success("Agent imported successfully")
            else:
                st.error(
                    "Failed to import agent. Ensure that you are uploading a valid YAML file"
                )

    with st.expander("Import Memory", False):
        memory_data = st.text_area(
            "Agent Memory in YAML or JSON",
            value="",
            height=170,
            key=f"{model_key}_memory_data",
        )
        overwite = st.toggle("Overwite", value=True, key=f"{model_key}_overide_memory")

        if st.button("Import", key=f"{model_key}_btn_import_memory"):
            # Call the function to import
            if result := call_action_walker_exec(
                agent_id,
                module_root,
                "import_memory",
                {"data": memory_data, "overwite": overwite},
            ):
                st.success("Agent memory imported successfully")
            else:
                st.error(
                    "Failed to import agent. Ensure that the  descriptor is in valid YAML format"
                )

            uploaded_file = st.file_uploader(
                "Upload file", key=f"{model_key}_agent_memory_upload"
            )

            if uploaded_file is not None:
                loaded_config = yaml.safe_load(uploaded_file)
                if loaded_config:
                    st.write(loaded_config)
                    if result := call_action_walker_exec(
                        agent_id, module_root, "import_memory", {"data": memory_data}
                    ):
                        st.success("Agent memory imported successfully")
                    else:
                        st.error(
                            "Failed to import agent memory. Ensure that you are uploading a valid YAML file"
                        )
                else:
                    st.error("File is invalid. Please upload a valid YAML file")

    with st.expander("Export Memory", False):
        # User input and toggle
        session_id = st.text_input(
            "Session ID (optional)", value="", key=f"{model_key}_export_session_id"
        )
        export_json = st.toggle(
            "Export as JSON", value=True, key=f"{model_key}_export_json"
        )

        # Toggle label adjustment
        toggle_label = "Export as JSON" if export_json else "Export as YAML"
        st.caption(f"**{toggle_label} enabled**")

        if st.button("Export", key=f"{model_key}_btn_export_memory"):
            # Prepare parameters
            params = {"session_id": session_id, "json": export_json}

            # Call the function to export memory
            result = call_action_walker_exec(
                agent_id, module_root, "export_memory", params
            )

            # Log results and provide download options
            if result and "memory" in result:
                st.success("Agent memory exported successfully!")

                # Process the first two entries of memory
                memory_entries = result["memory"][:2]  # First 2 entries
                if export_json:
                    # JSON display
                    st.json(memory_entries)

                    # Prepare downloadable JSON file
                    json_data = json.dumps(result, indent=4)
                    json_file = BytesIO(json_data.encode("utf-8"))
                    st.download_button(
                        label="Download JSON File",
                        data=json_file,
                        file_name="exported_memory.json",
                        mime="application/json",
                        key="download_json",
                    )
                else:
                    # YAML display
                    yaml_data = yaml.dump(memory_entries, sort_keys=False)
                    st.code(yaml_data, language="yaml")

                    # full memory dump
                    full_yaml_data = yaml.dump(result, sort_keys=False)

                    # Prepare downloadable YAML file
                    yaml_file = BytesIO(full_yaml_data.encode("utf-8"))
                    st.download_button(
                        label="Download YAML File",
                        data=yaml_file,
                        file_name="exported_memory.yaml",
                        mime="application/x-yaml",
                        key="download_yaml",
                    )
            else:
                st.error(
                    "Failed to export agent memory. Please check your inputs and try again."
                )

    with st.expander("Memory Healthcheck", False):
        # User input fields
        session_id = st.text_input(
            "Session ID (optional)", value="", key=f"{model_key}_healthcheck_session_id"
        )
        verbose = st.checkbox(
            "Verbose", value=False, key=f"{model_key}_healthcheck_verbose"
        )

        if st.button("Run Healthcheck", key=f"{model_key}_btn_healthcheck"):
            # Prepare parameters
            params = {"session_id": session_id, "verbose": verbose}

            # Call the function for healthcheck
            result = call_action_walker_exec(
                agent_id, module_root, "memory_healthcheck", params
            )

            # Display results
            if result:
                st.success("Memory healthcheck completed successfully!")

                # Dynamically display key-value pairs
                for key, value in result.items():
                    st.write(f"**{key}:** {value}")
            else:
                st.error(
                    "Failed to run memory healthcheck. Please check your inputs or try again."
                )

    with st.expander("Delete Agent", False):
        if st.button(
            "Delete Agent", key=f"{model_key}_btn_delete_agent", disabled=(not agent_id)
        ):
            # Call the function to purge
            if result := call_action_walker_exec(
                agent_id, module_root, "delete_agent", {"agent_id": agent_id}
            ):
                st.success("Agent deleted successfully")
            else:
                st.error(
                    "Failed to delete agent. Ensure that there is something to refresh or check functionality"
                )

    # Add update button to apply changes
    app_update_action(agent_id, action_id)


def classify_data(data: Union[Dict[str, Any], List[Dict[str, Any]]]) -> str:
    """
    Classifies input data into predefined categories.

    Args:
        data (Union[Dict[str, Any], List[Dict[str, Any]]]): The input data to classify.

    Returns:
        str: The category of the data. Possible values are "descriptor", "knowledge", "memory", or "unknown".
    """

    if isinstance(data, dict):
        if "actions" in data and "name" in data:
            return "descriptor"
    elif isinstance(data, list):
        for item in data:
            if isinstance(item, dict):
                if "metadata" in item and "text" in item:
                    return "knowledge"
                elif "frame" in item:
                    return "memory"
    return "unknown"
