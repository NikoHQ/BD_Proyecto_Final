import json
import re
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / 'SGCD_objetivo.puml'
OUTPUT = ROOT / 'UML_objetivo.mdj'


def uid():
    return uuid.uuid4().hex


def ref(value):
    return {'$ref': value}


def parse_entities(text):
    entities = {}
    for match in re.finditer(r'entity\s+(\w+)\s*\{(.*?)\n  \}', text, re.S):
        name, body = match.groups()
        columns = []
        for line in body.splitlines():
            line = line.strip()
            if not line or line == '--' or line.startswith('Nota:'):
                continue
            line = line.replace('* ', '', 1)
            field = re.match(r'(\w+)\s*:\s*([A-Z0-9]+)(?:\(([^)]*)\))?', line)
            if not field:
                continue
            column, kind, length = field.groups()
            columns.append({
                'name': column,
                'type': kind,
                'length': length or '',
                'primaryKey': line.startswith('*'),
                'foreignKey': 'FK' in line,
                'nullable': 'opcional' in line.lower(),
            })
        entities[name] = columns
    return entities


def style(fill='#E5F0FF'):
    return {
        'lineColor': '#718096',
        'fillColor': fill,
        'fontColor': '#24334B',
        'font': 'Arial;14;0',
        'parentStyle': False,
        'showShadow': False,
    }


RELATIONS = [
    ('RECINTO', 'HORARIO', 'FK: ID_RECINTO.'),
    ('RECINTO', 'CANCHA', 'FK: ID_RECINTO.'),
    ('DEPORTE', 'MODALIDAD', 'FK: ID_DEPORTE.'),
    ('CANCHA', 'CANCHA_MODALIDAD', 'FK: ID_CANCHA.'),
    ('MODALIDAD', 'CANCHA_MODALIDAD', 'FK: ID_MODALIDAD.'),
    ('CANCHA', 'TARIFA', 'FK: ID_CANCHA.'),
    ('MODALIDAD', 'TARIFA', 'FK: ID_MODALIDAD.'),
    ('CANCHA', 'CANCHA_COMPONENTE', 'FK: ID_CANCHA_GRANDE.'),
    ('CANCHA', 'CANCHA_COMPONENTE', 'FK: ID_CANCHA_PEQUENA.'),
    ('USUARIO', 'CLIENTE', 'FK: ID_USUARIO.'),
    ('USUARIO', 'ADMINISTRADOR', 'FK: ID_USUARIO.'),
    ('CLIENTE', 'RESERVA', 'FK: ID_CLIENTE.'),
    ('ADMINISTRADOR', 'RESERVA', 'FK: ID_ADMINISTRADOR.'),
    ('CANCHA', 'RESERVA', 'FK: ID_CANCHA.'),
    ('MODALIDAD', 'RESERVA', 'FK: ID_MODALIDAD.'),
    ('RESERVA', 'PAGO', 'FK: ID_RESERVA.'),
    ('ADMINISTRADOR', 'AUDITORIA_CLIENTE', 'ID_ADMINISTRADOR informativo.'),
]


GROUPS = {
    '01 Primera forma normal': list(parse_entities(SOURCE.read_text(encoding='utf-8'))),
    '02 Segunda forma normal': list(parse_entities(SOURCE.read_text(encoding='utf-8'))),
    '03 Tercera forma normal': list(parse_entities(SOURCE.read_text(encoding='utf-8'))),
    '04 Modelo objetivo completo': list(parse_entities(SOURCE.read_text(encoding='utf-8'))),
}

DIAGRAM_DOCS = {
    '01 Primera forma normal': 'Atributos atomicos, sin grupos repetidos y una clave primaria por tabla. Las relaciones N:M se representan con tablas puente.',
    '02 Segunda forma normal': 'Los atributos dependen de la clave completa. CANCHA_MODALIDAD y CANCHA_COMPONENTE separan relaciones compuestas.',
    '03 Tercera forma normal': 'Los datos descriptivos se mantienen en su propia tabla. Reserva conserva solo referencias y el importe historico.',
    '04 Modelo objetivo completo': 'Modelo final que se usara para adaptar el backend de Nico y el frontend de Eric.',
}


def build_view(entity, model_id, diagram_id, left, top):
    width = 430
    height = 55 + len(entity['columns']) * 22
    view_id = uid()
    label_id = uid()
    compartment_id = uid()
    label = {
        '_type': 'LabelView', '_id': label_id, '_parent': ref(view_id),
        'model': ref(entity['_id']), **style('#E5F0FF'),
        'left': left + 8, 'top': top + 8, 'width': width - 16,
        'height': 20, 'text': entity['name'], 'horizontalAlignment': 0,
    }
    compartment = {
        '_type': 'ERDColumnCompartmentView', '_id': compartment_id,
        '_parent': ref(view_id), 'model': ref(entity['_id']),
        **style('#E5F0FF'), 'left': left, 'top': top + 35,
        'width': width, 'height': height - 35, 'subViews': [],
    }
    for index, column in enumerate(entity['columns']):
        column_view = {
            '_type': 'ERDColumnView', '_id': uid(),
            '_parent': ref(compartment_id), 'model': ref(column['_id']),
            **style('#E5F0FF'), 'left': left + 8,
            'top': top + 40 + index * 22, 'width': width - 16, 'height': 20,
        }
        compartment['subViews'].append(column_view)
    return {
        '_type': 'ERDEntityView', '_id': view_id, '_parent': ref(diagram_id),
        'model': ref(entity['_id']), 'subViews': [label, compartment],
        **style('#E5F0FF'), 'left': left, 'top': top,
        'width': width, 'height': height,
        'nameLabel': ref(label_id), 'columnCompartment': ref(compartment_id),
    }


def build_relation(parent, child, note, entities, diagram_id):
    relation_id = uid()
    return {
        '_type': 'ERDRelationship', '_id': relation_id,
        '_parent': ref(entities[child]['_id']), 'documentation': note,
        'end1': {
            '_type': 'ERDRelationshipEnd', '_id': uid(), '_parent': ref(relation_id),
            'reference': ref(entities[parent]['_id']),
        },
        'end2': {
            '_type': 'ERDRelationshipEnd', '_id': uid(), '_parent': ref(relation_id),
            'reference': ref(entities[child]['_id']), 'cardinality': '0..*',
        },
        'identifying': False,
    }


def main():
    parsed = parse_entities(SOURCE.read_text(encoding='utf-8'))
    project_id = uid()
    model_id = uid()
    project = {
        '_type': 'Project', '_id': project_id,
        'name': 'SGCD - modelo objetivo del equipo', 'ownedElements': [],
    }
    model = {
        '_type': 'ERDDataModel', '_id': model_id, '_parent': ref(project_id),
        'name': 'Modelo relacional objetivo', 'ownedElements': [],
    }
    project['ownedElements'].append(model)
    entities = {}
    for name, columns in parsed.items():
        entity = {
            '_type': 'ERDEntity', '_id': uid(), '_parent': ref(model_id),
            'name': name, 'documentation': 'Entidad del modelo objetivo del equipo.',
            'columns': [], 'ownedElements': [],
        }
        for column in columns:
            item = {
                '_type': 'ERDColumn', '_id': uid(), '_parent': ref(entity['_id']),
                'name': column['name'], 'type': column['type'],
                'length': column['length'], 'nullable': column['nullable'],
                'primaryKey': column['primaryKey'],
                'foreignKey': column['foreignKey'], 'unique': False,
            }
            entity['columns'].append(item)
        entities[name] = entity
        model['ownedElements'].append(entity)

    for parent, child, note in RELATIONS:
        relation = build_relation(parent, child, note, entities, model_id)
        entities[child]['ownedElements'].append(relation)

    for group_index, (diagram_name, names) in enumerate(GROUPS.items()):
        diagram_id = uid()
        diagram = {
            '_type': 'ERDDiagram', '_id': diagram_id, '_parent': ref(model_id),
            'name': diagram_name, 'defaultDiagram': group_index == 0,
            'documentation': DIAGRAM_DOCS[diagram_name],
            'ownedViews': [],
        }
        view_map = {}
        for index, name in enumerate(names):
            view = build_view(entities[name], model_id, diagram_id, 70 + (index % 3) * 590, 80 + (index // 3) * 430)
            diagram['ownedViews'].append(view)
            view_map[name] = view
        for parent, child, note in RELATIONS:
            if parent not in view_map or child not in view_map:
                continue
            relation = next(rel for rel in entities[child]['ownedElements'] if rel.get('_type') == 'ERDRelationship' and rel['documentation'] == note and rel['end1']['reference']['$ref'] == entities[parent]['_id'])
            relation_view = {
                '_type': 'ERDRelationshipView', '_id': uid(), '_parent': ref(diagram_id),
                'model': ref(relation['_id']), **style('#FFFFFF'),
                'head': ref(view_map[child]['_id']), 'tail': ref(view_map[parent]['_id']),
                'points': f"{view_map[parent]['left'] + 215}:{view_map[parent]['top'] + 30};{view_map[child]['left'] + 215}:{view_map[child]['top'] + 30}",
                'subViews': [],
            }
            diagram['ownedViews'].insert(0, relation_view)
        model['ownedElements'].append(diagram)

    OUTPUT.write_text(json.dumps(project, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'{len(parsed)} entidades escritas en {OUTPUT}')


if __name__ == '__main__':
    main()
