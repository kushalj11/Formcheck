FormCheck is a native iOS app that analyzes barbell lifting technique entirely on device using computer vision. 

Built with SwiftUI, AVFoundation, and Apple's Vision framework, it tracks nineteen body joints frame by frame, draws a live skeleton overlay with coaching cues while you record, and segments each set into individual reps from the motion of the hips or the bar. Every rep is checked against form standards from Starting Strength, including squat depth, lockout, back angle, bar path over mid foot, knee tracking, head position, and bench press touch and bar path, using angle measurements that are corrected for a 45 degree camera angle and scaled to the lifter's own body proportions.

Results show a form score for the set and for each rep, the measured value behind every fault, the exact video frame where it happened with the involved joints highlighted, and a plain explanation of why it matters and how to fix it for users to have a helpful mentor. 
