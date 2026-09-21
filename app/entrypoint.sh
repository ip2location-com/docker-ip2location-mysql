#!/bin/bash

if [ "$#" -gt 0 ]; then
	exec "$@"
fi

exec bash /app/main.sh
