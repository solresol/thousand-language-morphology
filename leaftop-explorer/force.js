
var svg = d3.select("svg"),
    width = +svg.attr("width"),
    height = +svg.attr("height");

var simulation = d3.forceSimulation()
    .force("link", d3.forceLink().id(function (d) {
        return d.id;
    }))
    .force("charge", d3.forceManyBody().strength(-200))
    .force("center", d3.forceCenter(width / 2, height / 2));

d3.json(JSON_FILE, function (error, graph) {
    if (error) throw error;
    console.log(graph);

    var link = svg.append("g")
        .attr("class", "links")
        .selectAll("line")
        .data(graph.links)
        .enter().append("line");

    var node = svg.selectAll(".node")
        .data(graph.nodes)
	.enter().append("g")
        .attr("class", "node")
        .call(d3.drag()
            .on("start", dragstarted)
            .on("drag", dragged)
            .on("end", dragended));

    node.append("a")
        .attr("xlink:href", function (d) { return d.id + ".html"; })    
	.append("circle")
        .attr("r", function (d) { return Math.sqrt(d.size) / 2; })
        .style("fill", function (d) { return d.color; })

    node.append("title")
        .text(function (d) {
            return d.id;
        });

    node.append("text")
        .attr("dx", 12)
        .attr("dy", ".35em")
        .text(function (d) { return d.name; });

    link.append("title")
	.text(function (d) {
	    return d.value;
	});

/*
    var node = svg.append("g")
        .attr("class", "nodes")
        .selectAll("circle")
        .data(graph.nodes)
        .enter().append("circle")
        .attr("r", function (d) { return Math.sqrt(d.size) / 2; })
        .style("fill", function (d) { return d.color; })
        .call(d3.drag()
            .on("start", dragstarted)
            .on("drag", dragged)
            .on("end", dragended));

    node.append("title")
        .text(function (d) {
            return d.id;
        });

    node.append("text")
        .attr("dx", 12)
        .attr("dy", ".35em")
        .text(function (d) { return d.name; });
*/


    

    simulation
        .nodes(graph.nodes)
        .on("tick", ticked);

    simulation.force("link")
        .links(graph.links);

    function ticked() {
        link
            .attr("x1", function (d) {
                return d.source.x;
            })
            .attr("y1", function (d) {
                return d.source.y;
            })
            .attr("x2", function (d) {
                return d.target.x;
            })
            .attr("y2", function (d) {
                return d.target.y;
            });

        node
	    .attr("transform", function(d) { return "translate(" + d.x + "," + d.y + ")"; })
            .attr("cx", function (d) {
                return d.x;
            })
            .attr("cy", function (d) {
                return d.y;
            });
    }
});

function dragstarted(d) {
    if (!d3.event.active) simulation.alphaTarget(0.3).restart();
    d.fx = d.x;
    d.fy = d.y;
}

function dragged(d) {
    d.fx = d3.event.x;
    d.fy = d3.event.y;
}

function dragended(d) {
    if (!d3.event.active) simulation.alphaTarget(0);
    d.fx = null;
    d.fy = null;
}
