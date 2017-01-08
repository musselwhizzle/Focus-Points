Contributing as a Developer
=======
Thank you for considering to contribute to the project. To make things go smoother for all involved, please try to follow the guidelines here. 

1. Before you begin work, file an Issue in Github with whatever it is you want to do. If the Issue is for changing a feature for personal prefernce, get approval before starting. If not, it's possible the code/change will not be accepted. If the Issue is a bug fix, it will most likely be accepted. 
2. All Pull Requests must have an Issue and focus on a single task. Pull Requests which are not targeted to a single task and change multiple isolated Issues will not be accepted. 
3. Follow the naming convention that's already in place such as helloWorld and not hello_world.
4. All functions must have "javadoc" style documents that go along with it. Write a short description what the function does, what params it takes, and the possible return values. If a return is a table, list what properties the table can have. 
5. Do not refactor code just because. If something needs refactored, file an Issue and get approval.


Using Git - A typical workflow
=======
When you begin work on a new Issue, create a branch for this based off of master. "git checkout -b my_issue". "git push -u origin my_issue". Make all of your changes here in this branch. When it comes time put these changes into the master repo, make sure your master is up to date. "git checkout master". "git fetch". "git pull". If there are changes in master, you'll need to merge those into your branch. "git checkout my_issue". "git merge master". If there are conflicts, those will need to be resolve "git mergetool". Resolve the conflicts and "git commit". You're now ready to make a Pull Request from your branch into master. 