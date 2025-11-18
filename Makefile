.PHONY: help list clone pull commit push rebuild blog-build up down restart logs status clean

REPOS_FILE := repos.txt

help:
	@echo "🏠 Sieciowiec VPS Manager"
	@echo ""
	@echo "Repository Management:"
	@echo "  make list                     - List all repos from repos.txt"
	@echo "  make clone [REPO=name]        - Clone repo(s). No REPO = clone all"
	@echo "  make pull [REPO=name]         - Pull updates. No REPO = pull all"
	@echo "  make commit REPO=name MSG='msg' - Commit changes in specific repo"
	@echo "  make push [REPO=name]         - Push to GitHub. No REPO = push all"
	@echo ""
	@echo "Docker Management:"
	@echo "  make up                       - Start all containers"
	@echo "  make down                     - Stop all containers"
	@echo "  make restart [SVC=name]       - Restart service(s)"
	@echo "  make rebuild [SVC=name]       - Rebuild Docker image(s)"
	@echo "  make blog-build               - Build blog with Zola"
	@echo "  make logs [SVC=name]          - Show logs"
	@echo "  make status                   - Show container status"
	@echo "  make clean                    - Clean Docker resources"
	@echo ""
	@echo "Examples:"
	@echo "  make clone REPO=rapidmaker"
	@echo "  make commit REPO=blog MSG='Add new post'"
	@echo "  make push REPO=rapidmaker"
	@echo "  make rebuild SVC=rapidmaker"

# ============================================
# REPOSITORY OPERATIONS
# ============================================

list:
	@echo "📋 Repositories in $(REPOS_FILE):"
	@while IFS='|' read -r path repo branch || [ -n "$$path" ]; do \
		[ -z "$$path" ] || [ "$${path#\#}" != "$$path" ] && continue; \
		name=$$(basename $$path); \
		if [ -d "$$path/.git" ]; then \
			echo "  ✅ $$name ($$branch) - cloned"; \
		else \
			echo "  ⬜ $$name ($$branch) - not cloned"; \
		fi; \
	done < $(REPOS_FILE)

clone:
	@if [ -n "$(REPO)" ]; then \
		$(MAKE) _clone-single REPO=$(REPO); \
	else \
		$(MAKE) _clone-all; \
	fi

_clone-all:
	@echo "📥 Cloning all repositories..."
	@while IFS='|' read -r path repo branch || [ -n "$$path" ]; do \
		[ -z "$$path" ] || [ "$${path#\#}" != "$$path" ] && continue; \
		if [ -d "$$path/.git" ]; then \
			echo "⏭️  Skipping $$path (already exists)"; \
		else \
			echo "📦 Cloning $$repo → $$path"; \
			mkdir -p "$$(dirname $$path)"; \
			git clone -b $$branch $$repo $$path; \
		fi; \
	done < $(REPOS_FILE)
	@echo "✅ Done"

_clone-single:
	@found=0; \
	while IFS='|' read -r path repo branch || [ -n "$$path" ]; do \
		[ -z "$$path" ] || [ "$${path#\#}" != "$$path" ] && continue; \
		name=$$(basename $$path); \
		if [ "$$name" = "$(REPO)" ]; then \
			found=1; \
			if [ -d "$$path/.git" ]; then \
				echo "⏭️  $$name already cloned"; \
			else \
				echo "📦 Cloning $$repo → $$path"; \
				mkdir -p "$$(dirname $$path)"; \
				git clone -b $$branch $$repo $$path; \
			fi; \
			break; \
		fi; \
	done < $(REPOS_FILE); \
	if [ $$found -eq 0 ]; then \
		echo "❌ Repository '$(REPO)' not found in $(REPOS_FILE)"; \
		exit 1; \
	fi

pull:
	@if [ -n "$(REPO)" ]; then \
		$(MAKE) _pull-single REPO=$(REPO); \
	else \
		$(MAKE) _pull-all; \
	fi

_pull-all:
	@echo "📥 Pulling all repositories..."
	@while IFS='|' read -r path repo branch || [ -n "$$path" ]; do \
		[ -z "$$path" ] || [ "$${path#\#}" != "$$path" ] && continue; \
		if [ -d "$$path/.git" ]; then \
			name=$$(basename $$path); \
			echo "🔄 Pulling $$name"; \
			cd $$path && git pull origin $$branch && cd - > /dev/null; \
		fi; \
	done < $(REPOS_FILE)
	@echo "✅ Done"

_pull-single:
	@found=0; \
	while IFS='|' read -r path repo branch || [ -n "$$path" ]; do \
		[ -z "$$path" ] || [ "$${path#\#}" != "$$path" ] && continue; \
		name=$$(basename $$path); \
		if [ "$$name" = "$(REPO)" ]; then \
			found=1; \
			if [ -d "$$path/.git" ]; then \
				echo "🔄 Pulling $$name"; \
				cd $$path && git pull origin $$branch && cd - > /dev/null; \
			else \
				echo "❌ Repository not cloned. Run: make clone REPO=$(REPO)"; \
				exit 1; \
			fi; \
			break; \
		fi; \
	done < $(REPOS_FILE); \
	if [ $$found -eq 0 ]; then \
		echo "❌ Repository '$(REPO)' not found in $(REPOS_FILE)"; \
		exit 1; \
	fi

commit:
	@if [ -z "$(REPO)" ]; then \
		echo "❌ Error: REPO required"; \
		echo "Usage: make commit REPO=name MSG='your message'"; \
		exit 1; \
	fi
	@if [ -z "$(MSG)" ]; then \
		echo "❌ Error: MSG required"; \
		echo "Usage: make commit REPO=$(REPO) MSG='your message'"; \
		exit 1; \
	fi
	@found=0; \
	while IFS='|' read -r path repo branch || [ -n "$$path" ]; do \
		[ -z "$$path" ] || [ "$${path#\#}" != "$$path" ] && continue; \
		name=$$(basename $$path); \
		if [ "$$name" = "$(REPO)" ]; then \
			found=1; \
			if [ -d "$$path/.git" ]; then \
				echo "💾 Committing changes in $$name"; \
				cd $$path && git add -A && git commit -m "$(MSG)" && cd - > /dev/null; \
			else \
				echo "❌ Repository not cloned. Run: make clone REPO=$(REPO)"; \
				exit 1; \
			fi; \
			break; \
		fi; \
	done < $(REPOS_FILE); \
	if [ $$found -eq 0 ]; then \
		echo "❌ Repository '$(REPO)' not found in $(REPOS_FILE)"; \
		exit 1; \
	fi

push:
	@if [ -n "$(REPO)" ]; then \
		$(MAKE) _push-single REPO=$(REPO); \
	else \
		$(MAKE) _push-all; \
	fi

_push-all:
	@echo "🚀 Pushing all repositories..."
	@while IFS='|' read -r path repo branch || [ -n "$$path" ]; do \
		[ -z "$$path" ] || [ "$${path#\#}" != "$$path" ] && continue; \
		if [ -d "$$path/.git" ]; then \
			name=$$(basename $$path); \
			echo "📤 Pushing $$name"; \
			cd $$path && git push origin $$branch && cd - > /dev/null || true; \
		fi; \
	done < $(REPOS_FILE)
	@echo "✅ Done"

_push-single:
	@found=0; \
	while IFS='|' read -r path repo branch || [ -n "$$path" ]; do \
		[ -z "$$path" ] || [ "$${path#\#}" != "$$path" ] && continue; \
		name=$$(basename $$path); \
		if [ "$$name" = "$(REPO)" ]; then \
			found=1; \
			if [ -d "$$path/.git" ]; then \
				echo "📤 Pushing $$name"; \
				cd $$path && git push origin $$branch && cd - > /dev/null; \
			else \
				echo "❌ Repository not cloned. Run: make clone REPO=$(REPO)"; \
				exit 1; \
			fi; \
			break; \
		fi; \
	done < $(REPOS_FILE); \
	if [ $$found -eq 0 ]; then \
		echo "❌ Repository '$(REPO)' not found in $(REPOS_FILE)"; \
		exit 1; \
	fi

# ============================================
# DOCKER OPERATIONS
# ============================================

up:
	docker compose up -d

down:
	docker compose down

restart:
	@if [ -n "$(SVC)" ]; then \
		docker compose restart $(SVC); \
	else \
		docker compose restart; \
	fi

rebuild:
	@if [ "$(SVC)" = "blog" ]; then \
		$(MAKE) blog-build; \
	elif [ -n "$(SVC)" ]; then \
		echo "🔨 Rebuilding $(SVC)..."; \
		docker compose build --no-cache $(SVC); \
		docker compose up -d $(SVC); \
	else \
		echo "🔨 Rebuilding all services..."; \
		docker compose build --no-cache; \
		docker compose up -d; \
	fi

blog-build:
	@echo "🔨 Building blog with Zola..."
	@docker run --rm \
		-v $(PWD)/services/blog:/project \
		-v $(PWD)/volumes/blog-content:/project/content \
		-w /project \
		ghcr.io/getzola/zola:v0.21.0 build
	@docker compose restart blog
	@echo "✅ Blog rebuilt and restarted"

logs:
	@if [ -n "$(SVC)" ]; then \
		docker compose logs -f --tail=100 $(SVC); \
	else \
		docker compose logs -f --tail=100; \
	fi

status:
	docker compose ps

clean:
	docker system prune -af
	docker volume prune -f
