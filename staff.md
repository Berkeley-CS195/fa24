---
layout: page
title: Staff
description: A listing of all the course staff members.
nav_order: 20
---

# Staff

## Instructors

{% assign instructors = site.staffers | where: 'role', 'Instructor' %}

<div class="role flex">
{% for staffer in instructors %}
{{ staffer }}
{% endfor %}

</div>

{% assign teaching_assistants = site.staffers | where: 'role', 'Teaching Assistant' %}
{% assign num_teaching_assistants = teaching_assistants | size %}

{% if num_teaching_assistants != 0 %}

## Teaching Assistants

<div class="role flex">

{% for staffer in teaching_assistants %}
{{ staffer }}
{% endfor %}
</div>

{% endif %}

{% assign bots = site.staffers | where: 'role', 'Bot' %}
{% assign num_bots = bots | size %}

{% if num_bots != 0 %}

## Bot

<div class="role flex">

{% for staffer in bots %}
{{ staffer }}
{% endfor %}
</div>

{% endif %}
