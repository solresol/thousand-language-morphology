flyers.pdf: flyers.tex content.tex
	xelatex flyers.tex

content.tex: content.sql
	psql -q -t -d thousand_language -f content.sql > content.tex
