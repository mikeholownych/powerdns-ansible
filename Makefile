install:
	pip install -r requirements.txt

test:
	pytest -q --cov=src --cov-report=term-missing

run:
	python src/cli.py run

serve:
	python src/cli.py serve

lint:
	black src tests
