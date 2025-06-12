# Instructor Guide: The Tao of Spark Workshop

> *"The best teachers are those who show you where to look, but don't tell you what to see."* - Alexandra K. Trenfor

This comprehensive instructor guide provides everything needed to deliver a world-class Spark DSL workshop. Whether you're an experienced trainer or teaching your first workshop, this guide ensures consistent, high-quality delivery.

## Pre-Workshop Preparation

### 4 Weeks Before Workshop

**Venue and Technology Setup**
- [ ] Confirm venue with reliable WiFi (minimum 50 Mbps for 16 participants)
- [ ] Test projector/screen setup with presenter's laptop
- [ ] Arrange tables for groups of 4 participants
- [ ] Ensure power outlets accessible for all participants
- [ ] Set up whiteboard/flipchart areas for each group

**Participant Communications**
- [ ] Send welcome email with pre-workshop checklist
- [ ] Share required reading: "Foundations" section of The Tao of Spark
- [ ] Provide development environment setup instructions
- [ ] Collect participant information forms
- [ ] Create private Slack/Discord workspace for workshop

**Material Preparation**
- [ ] Print participant workbooks (one per person)
- [ ] Prepare USB drives with complete code repository
- [ ] Test all workshop code examples on clean development environment
- [ ] Prepare name tags, markers, sticky notes, and notebooks
- [ ] Create group assignment cards

### 1 Week Before Workshop

**Final Preparations**
- [ ] Send reminder email with final logistics
- [ ] Confirm catering arrangements (lunch + 2 coffee breaks daily)
- [ ] Test screen sharing and recording setup
- [ ] Review participant backgrounds and adjust examples accordingly
- [ ] Prepare contingency plans for common technical issues

**Instructor Team Briefing**
- [ ] Review role assignments for lead and assistant instructors
- [ ] Walk through entire curriculum and timing
- [ ] Practice difficult live coding sessions
- [ ] Establish hand signals and communication protocols
- [ ] Review participant list and any special needs

### Day of Workshop

**Setup (2 hours before start)**
- [ ] Arrive early to test all technology
- [ ] Arrange room for optimal collaboration
- [ ] Set up registration/welcome table
- [ ] Test WiFi with multiple devices
- [ ] Prepare coffee and welcome refreshments
- [ ] Set up recording equipment if sessions will be recorded

---

## Daily Facilitation Guides

### Day 1: Facilitation Guide

#### Pre-Day Preparation
- Review participant pre-work completion
- Prepare live coding environment for task management DSL
- Set up group assignments (mix experience levels)
- Have backup plans ready for participants with setup issues

#### Opening Circle (9:00-9:30)
**Energy Level: Building rapport and excitement**

**Facilitator Notes:**
- Stand and move around the room during introductions
- Take notes on flip charts about participant domains and interests
- Use participants' actual examples throughout the workshop
- Watch for anxiety about technical level - reassure that we start simple

**Script Opening:**
> "Welcome to what might be the most transformative week of your development career. You're here because you've felt the power of DSLs as a user. This week, you become a DSL creator. By Friday, you'll think in languages, not just code."

**Icebreaker Protocol:**
1. Have participants introduce themselves (2 minutes each)
2. Note interesting domains on whiteboard
3. Create energy by highlighting the diversity of problems we'll solve
4. Address the elephant in the room: "Yes, this is advanced material, but we'll build understanding step by step"

#### Foundation Concepts (9:30-10:30)
**Energy Level: Building conceptual foundation**

**Key Teaching Points:**
- **Mindset Shift**: This is the most important learning of the day
- **Concrete Examples**: Use participant domains when possible
- **Interactive**: Ask "Who has experienced this frustration?" throughout

**Live Demo Script:**
```
"Let me show you the exact moment when everything clicked for me about DSLs..."

[Show evolution from config files to DSL with real example]

"Notice what happened to my thinking. I stopped thinking 'How do I store this configuration?' and started thinking 'How should a domain expert express their intent?'"
```

**Red Flags to Watch For:**
- Participants focusing on implementation rather than interface design
- Questions about macro internals (redirect: "Great question for Day 3")
- Confusion about validation vs. business logic (clarify: "Validation is about the DSL syntax, business logic is what the DSL enables")

#### Live Coding Session (10:45-12:00)
**Energy Level: Engaged learning through doing**

**Setup:**
- Use large font (18pt minimum) for all code
- Code slowly - let people follow along
- Pause frequently for questions
- Have assistant instructors circulate to help

**Teaching Rhythm:**
1. **Explain what we're building** (2 minutes)
2. **Build one small piece** (5-7 minutes)
3. **Test it immediately** (2 minutes)
4. **Reflect on what we learned** (3 minutes)
5. **Repeat**

**Common Failure Points:**
- **Typos in live coding**: Have backup branches ready, don't spend time debugging
- **Participants falling behind**: Assistant instructors should help catch people up
- **Scope creep**: Resist adding "just one more feature"

**Key Moment - The "Magic" Reveal:**
When you first show the DSL being used, pause and ask:
> "What does this feel like compared to the configuration approaches we discussed earlier?"

Let participants experience the revelation themselves.

#### Afternoon Lab Strategy
**Energy Level: Sustained engagement through personal relevance**

**Lab Introduction (5 minutes):**
> "This isn't a coding exercise - it's a language design exercise. Your personal development environment is complex enough to be interesting, personal enough to be motivating, and familiar enough that you can focus on the DSL design rather than domain understanding."

**Circulation Protocol:**
- Visit each participant at least 3 times during the lab
- Ask "What feels natural vs. forced about your DSL?" rather than "Are you stuck?"
- Help with philosophy, not just syntax
- Celebrate interesting design decisions publicly

**Common Interventions:**
- **Overthinking domain modeling**: "Start simple, add complexity gradually"
- **Implementation focus**: "What would the usage look like? Start there."
- **Validation paralysis**: "Add validation after the basic structure works"

**Energy Management:**
- Watch for afternoon slump around 2:30 PM
- Use the 3:00 PM break strategically
- Encourage pair programming if energy drops
- Share interesting solutions to reinvigorate the room

#### Day 1 Wrap-up Strategy
**Goal: Leave with confidence and excitement**

**Pair Sharing Protocol:**
1. 7 minutes per person to demo their DSL
2. Partner asks: "What feels most natural about this DSL?"
3. Switch and repeat
4. Each pair shares one insight with the group

**Closing Energy:**
> "You've just crossed a significant threshold. You're no longer thinking like DSL users - you're thinking like DSL designers. Tomorrow we take these skills to real business problems."

### Day 2-5: Detailed Facilitation Notes

[Similar detailed guides for remaining days...]

---

## Troubleshooting Guide

### Technical Issues

**WiFi Problems**
- Have mobile hotspot backup ready
- Pre-download all dependencies for common scenarios
- Create offline development environment on USB drives

**Development Environment Issues**
- Maintain list of common Elixir installation problems by OS
- Have Docker containers ready with complete development environment
- Assistant instructors should be expert at environment troubleshooting

**Code Compilation Issues**
- Maintain git repository with working solutions for every step
- Use `git worktree` to have multiple branches checked out simultaneously
- Don't debug live - switch to working branch and explain the issue separately

### Learning and Engagement Issues

**Participant Falling Behind**
1. Pair them with someone slightly ahead
2. Provide simplified version of current exercise
3. Focus on understanding concepts rather than completing all details
4. Schedule individual check-in during break

**Participant Moving Too Fast**
1. Ask them to help others (builds community)
2. Provide stretch challenges
3. Have them explore edge cases
4. Ask them to document patterns they discover

**Low Energy/Engagement**
1. Change physical environment (stand up, move around)
2. Switch to pair programming
3. Share a success story from another workshop
4. Connect current work to participant's stated goals

**Conceptual Confusion**
1. Go back to concrete examples in their domain
2. Draw the concepts on whiteboard
3. Have them explain it to a partner
4. Use analogies from their background

### Group Dynamics

**Dominant Participant**
- Use timeboxed sharing (timer visible)
- Direct questions to others: "Sarah, what's your experience with this?"
- Leverage their knowledge: "John, you've got this - can you help others during the lab?"

**Quiet Participant**
- Check in privately during breaks
- Ask direct questions in small groups first
- Pair with encouraging partner
- Validate their contributions publicly when they do speak

**Technical Showing Off**
- Acknowledge expertise: "That's a great advanced technique"
- Redirect: "Let's master the fundamentals first, then explore that"
- Use their knowledge to help others rather than show complexity

---

## Assessment and Progress Tracking

### Daily Assessment Criteria

**Day 1: Foundation Understanding**
- [ ] Can explain DSL mindset vs. traditional programming
- [ ] Built working personal DSL with validation
- [ ] Demonstrates domain modeling thinking
- [ ] Shows excitement about DSL potential

**Day 2: Business Application**
- [ ] Designed DSL for actual business problem
- [ ] Applied advanced entity and transformer patterns
- [ ] Shows understanding of production considerations
- [ ] Can articulate business value of DSL approach

**Day 3: Architectural Thinking**
- [ ] Designed extensible DSL architecture
- [ ] Built working transformers and verifiers
- [ ] Understands extension patterns
- [ ] Shows systems thinking about DSL evolution

**Day 4: Production Readiness**
- [ ] Successfully deployed DSL-driven application
- [ ] Implemented comprehensive testing strategy
- [ ] Created team adoption materials
- [ ] Understands operational considerations

**Day 5: Future Mastery**
- [ ] Built AI-enhanced DSL prototype
- [ ] Designed sophisticated master project
- [ ] Shows leadership in helping others
- [ ] Demonstrates readiness for independent DSL development

### Progress Indicators

**Green Flags (Participant on track):**
- Asks questions about design rather than just syntax
- Helps other participants
- Makes connections between concepts and their work
- Shows increasing confidence in DSL design decisions

**Yellow Flags (Needs attention):**
- Focuses only on getting code to compile
- Seems overwhelmed by complexity
- Not participating in discussions
- Falling behind on exercises

**Red Flags (Intervention needed):**
- Can't explain basic DSL concepts
- Frustrated with workshop pace or content
- Disengaged from group activities
- Considering leaving workshop

### Intervention Strategies

**For Yellow Flag Participants:**
1. Individual check-in during break
2. Simplify current exercise to focus on core concepts
3. Pair with supportive partner
4. Provide additional context for why concepts matter

**For Red Flag Participants:**
1. Private conversation to understand challenges
2. Potentially modified learning path
3. Connect current struggle to eventual success
4. Consider whether workshop is right fit for their current level

---

## Materials and Resources

### Instructor Materials Checklist

**Physical Materials:**
- [ ] Instructor guide (this document)
- [ ] Participant workbooks (16 copies)
- [ ] Name tags and markers
- [ ] Sticky notes (multiple colors)
- [ ] Flip chart paper and markers
- [ ] Timer for timeboxed activities
- [ ] USB drives with complete code repository

**Digital Materials:**
- [ ] Slide decks for each day
- [ ] Complete code repository with solution branches
- [ ] Screen recording software setup
- [ ] Backup presentation laptop
- [ ] Workshop Slack/Discord workspace

**Contingency Materials:**
- [ ] Offline development environment containers
- [ ] Mobile hotspot for WiFi backup
- [ ] Alternative exercises if technology fails
- [ ] Contact information for technical support

### Participant Materials

**Pre-Workshop:**
- Development environment setup checklist
- Required reading assignments
- Pre-workshop survey
- Workshop schedule and logistics

**Daily Handouts:**
- Daily objectives and schedule
- Lab exercise instructions
- Code templates and starting points
- Resource lists and references

**Take-Home Package:**
- Complete source code repository
- Pattern library and design templates
- Resource collection for continued learning
- Community access information
- Certificate of completion

---

## Post-Workshop Follow-up

### Immediate Follow-up (Week 1)
- [ ] Send thank you email with complete materials
- [ ] Provide access to private community workspace
- [ ] Share session recordings (if participants consented)
- [ ] Send post-workshop survey for feedback

### Ongoing Support (Months 1-3)
- [ ] Monthly office hours with instructors
- [ ] Participant project showcase opportunities
- [ ] Advanced topic sessions based on interest
- [ ] Connection to broader Spark community

### Long-term Community Building (3+ months)
- [ ] Alumni network maintenance
- [ ] Advanced workshop opportunities
- [ ] Conference speaking opportunities for graduates
- [ ] Mentorship program for new DSL developers

---

## Instructor Development

### Required Instructor Qualifications

**Lead Instructor:**
- 5+ years Elixir experience with significant DSL development
- Experience teaching technical topics to adult learners
- Deep understanding of Spark framework and ecosystem
- Demonstrated ability to explain complex concepts clearly
- Strong facilitation and group management skills

**Assistant Instructors (2-3 recommended):**
- 2+ years Elixir experience with some DSL work
- Patient and supportive teaching style
- Strong debugging and troubleshooting skills
- Ability to provide individual help during lab sessions

### Instructor Preparation Program

**Week 1: Content Mastery**
- Complete all workshop exercises independently
- Study common failure points and solutions
- Practice live coding sessions
- Review participant demographics and backgrounds

**Week 2: Facilitation Skills**
- Practice workshop delivery with peer audience
- Develop personal teaching style within workshop framework
- Learn group management and intervention techniques
- Prepare for common questions and challenges

**Week 3: Integration and Polish**
- Full workshop run-through with feedback
- Refine timing and transitions
- Prepare contingency plans
- Final materials preparation

### Continuous Improvement

**After Each Workshop:**
- Conduct instructor team retrospective
- Update materials based on participant feedback
- Document successful interventions and teaching moments
- Share insights with broader instructor community

**Quarterly Reviews:**
- Analyze participant outcomes and success metrics
- Update curriculum based on Spark framework evolution
- Incorporate new community patterns and insights
- Refresh examples and case studies

This instructor guide ensures that every workshop delivery maintains the high quality and transformative experience that participants expect from The Tao of Spark intensive.

*Great teaching is the bridge between knowledge and understanding. Use this guide to build that bridge for your participants.*