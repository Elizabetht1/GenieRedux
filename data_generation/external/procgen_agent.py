
import gym
from tqdm import tqdm 
import numpy as np


import procgen 
from procgen.env import ENV_NAMES 

def procgen_agent_generator(env_name,
                            max_steps=100000,
                            num_levels=0,
                            start_level=0,
                            paint_vel_info=False,
                            use_generated_assets=False,
                            debug=False,
                           debug_mode=0,
                           center_agent=True,
                           use_sequential_levels=False,
                           distribution_mode="hard",
                           use_backgrounds=True,
                           restrict_themes=False,
                           use_monochrome_assets=False):
    """
    only supports creating a single enviornment 
    """
    if env_name not in ENV_NAMES:
        raise Exception(f"envionrment error {env_name} not in list of supported progen enviornments")
        
    env = gym.make(f"procgen:procgen-{env_name}",
                  num_levels=num_levels,
                   start_level=start_level, 
                   paint_vel_info=paint_vel_info,
                   use_generated_assets=use_generated_assets,
                   debug=debug,
                   debug_mode=debug_mode,
                   center_agent=center_agent,
                   use_sequential_levels=use_sequential_levels,
                   distribution_mode=distribution_mode,
                   use_backgrounds=use_backgrounds,
                   restrict_themes=restrict_themes,
                   use_monochrome_assets=use_monochrome_assets)
    
    obs = env.reset()
    done = False 
    for step in range(max_steps):
        if done:
            break

        ## sample a random action 
        act_  =  np.array(env.action_space.sample())
        img_, rew, done_, info_ = env.step(act_)
        done = done_ 

        yield img_, act_,rew, done_, info_
