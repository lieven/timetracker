# Time Tracker
Simple time tracker written for the first Showpad hackathon.

## About

Time Tracker is a simple status bar application for Mac OS X that helps you keep track of how you spent your day. The goal is to keep things as simple and generic as possible.

![Screenshot](Screenshot.png)

Time can be tracked for projects and tasks.
Using __projects__, you can get a global overview of your day. Using __tasks__, you can get a more detailed view of how your time on each project was spent.

The most recent used projects and tasks are shown on top. If your list of tasks or projects becomes longer than 5 items, older items are displayed in a submenu.

## Usage

First you need to add one or more projects and tasks. Selecting a project and/or task will start tracking. You can use _Stop Tracking_ to take a break.

Time is tracked for projects and tasks separately, but selecting a different project will stop tracking for the current task in the previous project.

Using _Copy Today's Log_, you can copy a textual overview to the clipboard of how long you've worked on each project and its subtasks. Example output looks like this:

	14/03/15

	Showpad iOS:  12:00-12:15: 15m
	- SPI-907:  12:00-12:10: 10m
	- SPI-877:  12:10-12:15: 5m
