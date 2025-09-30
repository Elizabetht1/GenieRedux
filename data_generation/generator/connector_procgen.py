## 

from generator.connector_base import BaseConnector
from external.procgen_agent import procgen_agent_generator
import cv2 

class ProcgenConnector(BaseConnector):
    def __init__(self,config=None
                ):
        if config is None:
            config = {
                "env": "coinrun",
                "version": "0.1.0",
                "is_high_difficulty": True,
                "agent_type": "random",
                "image_size": (32,32)
            }

        
        self.config = config
        self.name = config["name"]
        self.version = config["version"]
        self.image_size = config["image_size"]
        self.agent_type = config["agent_type"]

        # TODO implement an agent 
        if self.agent_type == "random":
            self.agent_generator = procgen_agent_generator 
        else: 
            raise Exception(f"agent type {self.agent_type} not supported")

        
    def get_name(self):
        return self.name

    def get_info(self):
        return self.config 


    def generator(self, instance_id, session_id, n_steps_max):
        for frame_id, (img_, act_,rew, done_, info_) in enumerate(self.agent_generator(env_name = self.name,max_steps = n_steps_max)):
            # print("\n",frame_id,"\n")
            if done_:
                break 
                
            if self.image_size is not None:
                img_ = cv2.resize(img_, self.image_size)
                
            yield {
                "src_frame_id": frame_id - 1,
                "tgt_frame_id": frame_id,
                "frame": img_,
                "action": int(act_),
                "session_end": frame_id == n_steps_max - 1,
                "done": done_,
                "procgen_info": info_,
                "reward" : rew,
                "extras": {}
            }
            