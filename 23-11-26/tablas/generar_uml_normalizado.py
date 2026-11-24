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


def parse_final():
    entities = {}
    text = SOURCE.read_text(encoding='utf-8')
    for match in re.finditer(r'entity\s+(\w+)\s*\{(.*?)\n  \}', text, re.S):
        name, body = match.groups()
        columns = []
        for raw in body.splitlines():
            line = raw.strip()
            if not line or line == '--' or line.startswith('Nota:'):
                continue
            primary = line.startswith('*')
            line = line.removeprefix('* ').strip()
            item = re.match(r'(\w+)\s*:\s*([A-Z0-9]+)(?:\(([^)]*)\))?', line)
            if not item:
                continue
            field, kind, length = item.groups()
            columns.append({
                'name': field,
                'type': kind,
                'length': length or '',
                'primaryKey': primary,
                'foreignKey': 'FK' in line,
                'nullable': 'opcional' in line.lower(),
            })
        entities[name] = columns
    return entities


def col(name, kind='VARCHAR2', length='', pk=False, fk=False, nullable=False):
    return {'name': name, 'type': kind, 'length': length, 'primaryKey': pk, 'foreignKey': fk, 'nullable': nullable}


def final_relations():
    return [
        ('RECINTO', 'HORARIO', 'FK: ID_RECINTO.'),
        ('HORARIO', 'BLOQUE_HORARIO', 'FK: ID_HORARIO.'),
        ('RECINTO', 'CANCHA', 'FK: ID_RECINTO.'),
        ('DEPORTE', 'MODALIDAD', 'FK: ID_DEPORTE.'),
        ('CANCHA', 'CANCHA_MODALIDAD', 'FK: ID_CANCHA.'),
        ('MODALIDAD', 'CANCHA_MODALIDAD', 'FK: ID_MODALIDAD.'),
        ('CANCHA', 'TARIFA', 'FK: ID_CANCHA.'),
        ('MODALIDAD', 'TARIFA', 'FK: ID_MODALIDAD.'),
        ('MODALIDAD', 'TORNEO', 'FK: ID_MODALIDAD.'),
        ('CANCHA', 'CANCHA_COMPONENTE', 'FK: ID_CANCHA_GRANDE.'),
        ('CANCHA', 'CANCHA_COMPONENTE', 'FK: ID_CANCHA_PEQUENA.'),
        ('USUARIO', 'CLIENTE', 'FK: ID_USUARIO.'),
        ('USUARIO', 'ADMINISTRADOR', 'FK: ID_USUARIO.'),
        ('CLIENTE', 'RESERVA', 'FK: ID_CLIENTE.'),
        ('ADMINISTRADOR', 'RESERVA', 'FK: ID_ADMINISTRADOR.'),
        ('CANCHA', 'RESERVA', 'FK: ID_CANCHA.'),
        ('MODALIDAD', 'RESERVA', 'FK: ID_MODALIDAD.'),
        ('TORNEO', 'RESERVA', 'FK: ID_TORNEO.'),
        ('RESERVA', 'PAGO', 'FK: ID_RESERVA.', '0..1'),
        ('ADMINISTRADOR', 'AUDITORIA_CLIENTE', 'ID_ADMINISTRADOR informativo.'),
        ('TORNEO', 'INSCRIPCION_TORNEO', 'FK: ID_TORNEO.'),
        ('CLIENTE', 'INSCRIPCION_TORNEO', 'FK: ID_CLIENTE.'),
    ]


def schemas():
    final = parse_final()
    n1 = {
        'RECINTO_CANCHA_HORARIO': [
            col('ID_RECINTO', 'NUMBER', pk=True), col('NOMBRE_RECINTO', 'VARCHAR2', '100'),
            col('DIRECCION_RECINTO', 'VARCHAR2', '150'), col('ID_CANCHA', 'NUMBER'),
            col('NOMBRE_CANCHA', 'VARCHAR2', '100'), col('ID_DEPORTE', 'NUMBER'),
            col('NOMBRE_DEPORTE', 'VARCHAR2', '50'), col('ID_MODALIDAD', 'NUMBER'),
            col('NOMBRE_MODALIDAD', 'VARCHAR2', '80'), col('DIA_SEMANA', 'NUMBER'),
            col('HORA_APERTURA', 'VARCHAR2', '5'), col('HORA_CIERRE', 'VARCHAR2', '5'),
        ],
        'CLIENTE_USUARIO': [
            col('ID_CLIENTE', 'NUMBER', pk=True), col('RUT_CLIENTE', 'NUMBER'),
            col('DV_CLIENTE', 'VARCHAR2', '1'), col('NOMBRE_CLIENTE', 'VARCHAR2', '100'),
            col('CORREO_CLIENTE', 'VARCHAR2', '150'), col('TELEFONO_CLIENTE', 'VARCHAR2', '20'),
            col('LOGIN', 'VARCHAR2', '50'), col('CLAVE_HASH', 'VARCHAR2', '255'),
        ],
        'ADMINISTRADOR': [
            col('ID_ADMINISTRADOR', 'NUMBER', pk=True), col('NOMBRE_ADMINISTRADOR', 'VARCHAR2', '100'),
            col('LOGIN', 'VARCHAR2', '50'), col('CLAVE_HASH', 'VARCHAR2', '255'),
        ],
        'RESERVA_PAGO': [
            col('ID_RESERVA', 'NUMBER', pk=True), col('ID_CLIENTE', 'NUMBER'),
            col('NOMBRE_CLIENTE', 'VARCHAR2', '100'), col('ID_CANCHA', 'NUMBER'),
            col('NOMBRE_CANCHA', 'VARCHAR2', '100'), col('ID_MODALIDAD', 'NUMBER'),
            col('NOMBRE_MODALIDAD', 'VARCHAR2', '80'), col('INICIO_RESERVA', 'DATE'),
            col('TERMINO_RESERVA', 'DATE'), col('IMPORTE_ACORDADO', 'NUMBER'),
            col('ID_PAGO', 'NUMBER'), col('IMPORTE_PAGO', 'NUMBER'),
            col('FECHA_PAGO', 'DATE'), col('MEDIO_PAGO', 'VARCHAR2', '20'),
        ],
        'AUDITORIA_CLIENTE': [
            col('ID_AUDITORIA', 'NUMBER', pk=True), col('ID_CLIENTE', 'NUMBER'),
            col('ID_ADMINISTRADOR', 'NUMBER'), col('ACCION', 'VARCHAR2', '10'),
            col('FECHA_EVENTO', 'DATE'), col('VALORES_ANTERIORES', 'VARCHAR2', '4000'),
            col('VALORES_NUEVOS', 'VARCHAR2', '4000'),
        ],
    }
    n2_names = ['RECINTO', 'HORARIO', 'BLOQUE_HORARIO', 'DEPORTE', 'MODALIDAD', 'CANCHA', 'CANCHA_MODALIDAD',
                'CANCHA_COMPONENTE', 'TARIFA', 'USUARIO', 'CLIENTE', 'ADMINISTRADOR',
                'RESERVA', 'PAGO']
    n2 = {name: final[name] for name in n2_names}
    n2_relations = [rel for rel in final_relations() if rel[2] != 'ID_ADMINISTRADOR informativo.']
    return n1, n2, final, n2_relations, final_relations()


def style(fill='#E5F0FF'):
    return {'lineColor': '#718096', 'fillColor': fill, 'fontColor': '#24334B',
            'font': 'Arial;14;0', 'parentStyle': False, 'showShadow': False}


def entity_model(name, columns, model_id):
    entity = {'_type': 'ERDEntity', '_id': uid(), '_parent': ref(model_id),
              'name': name, 'documentation': 'Entidad de la etapa de normalizacion.',
              'columns': [], 'ownedElements': []}
    for column in columns:
        entity['columns'].append({
            '_type': 'ERDColumn', '_id': uid(), '_parent': ref(entity['_id']),
            'name': column['name'], 'type': column['type'], 'length': column['length'],
            'nullable': column['nullable'], 'primaryKey': column['primaryKey'],
            'foreignKey': column['foreignKey'], 'unique': False,
        })
    return entity


def entity_view(entity, diagram_id, left, top):
    width = 430
    height = 55 + len(entity['columns']) * 22
    view_id, label_id, compartment_id = uid(), uid(), uid()
    label = {'_type': 'LabelView', '_id': label_id, '_parent': ref(view_id),
             'model': ref(entity['_id']), **style(), 'left': left + 8, 'top': top + 8,
             'width': width - 16, 'height': 20, 'text': entity['name'], 'horizontalAlignment': 0}
    compartment = {'_type': 'ERDColumnCompartmentView', '_id': compartment_id,
                   '_parent': ref(view_id), 'model': ref(entity['_id']), **style(),
                   'left': left, 'top': top + 35, 'width': width, 'height': height - 35,
                   'subViews': []}
    for index, column in enumerate(entity['columns']):
        compartment['subViews'].append({
            '_type': 'ERDColumnView', '_id': uid(), '_parent': ref(compartment_id),
            'model': ref(column['_id']), **style(), 'left': left + 8,
            'top': top + 40 + index * 22, 'width': width - 16, 'height': 20,
        })
    return {'_type': 'ERDEntityView', '_id': view_id, '_parent': ref(diagram_id),
            'model': ref(entity['_id']), 'subViews': [label, compartment], **style(),
            'left': left, 'top': top, 'width': width, 'height': height,
            'nameLabel': ref(label_id), 'columnCompartment': ref(compartment_id)}


def relation_model(parent, child, note, entities, child_cardinality='0..*'):
    rid = uid()
    relation = {'_type': 'ERDRelationship', '_id': rid, '_parent': ref(entities[child]['_id']),
                'documentation': note,
                'end1': {'_type': 'ERDRelationshipEnd', '_id': uid(), '_parent': ref(rid),
                         'reference': ref(entities[parent]['_id'])},
                'end2': {'_type': 'ERDRelationshipEnd', '_id': uid(), '_parent': ref(rid),
                         'reference': ref(entities[child]['_id']), 'cardinality': child_cardinality},
                'identifying': False}
    entities[child]['ownedElements'].append(relation)
    return relation


def build_stage(project, name, description, schema, relations):
    model_id = uid()
    model = {'_type': 'ERDDataModel', '_id': model_id, '_parent': ref(project['_id']),
             'name': name, 'ownedElements': []}
    project['ownedElements'].append(model)
    entities = {}
    for table, columns in schema.items():
        entities[table] = entity_model(table, columns, model_id)
        model['ownedElements'].append(entities[table])
    relationships = []
    for relation in relations:
        if relation[0] not in entities or relation[1] not in entities:
            continue
        cardinality = relation[3] if len(relation) > 3 else '0..*'
        relationships.append(relation_model(relation[0], relation[1], relation[2], entities, cardinality))
    diagram_id = uid()
    diagram = {'_type': 'ERDDiagram', '_id': diagram_id, '_parent': ref(model_id),
               'name': name, 'defaultDiagram': name.startswith('01'),
               'documentation': description, 'ownedViews': []}
    views = {}
    for index, table in enumerate(schema):
        views[table] = entity_view(entities[table], diagram_id, 70 + (index % 3) * 590,
                                   80 + (index // 3) * 430)
    for relation in relationships:
        parent = relation['end1']['reference']['$ref']
        child = relation['end2']['reference']['$ref']
        parent_name = next(name for name, entity in entities.items() if entity['_id'] == parent)
        child_name = next(name for name, entity in entities.items() if entity['_id'] == child)
        parent_view, child_view = views[parent_name], views[child_name]
        relation_view = {'_type': 'ERDRelationshipView', '_id': uid(), '_parent': ref(diagram_id),
                         'model': ref(relation['_id']), **style('#FFFFFF'),
                         'head': ref(child_view['_id']), 'tail': ref(parent_view['_id']),
                         'points': f"{parent_view['left'] + 215}:{parent_view['top'] + 30};{child_view['left'] + 215}:{child_view['top'] + 30}",
                         'subViews': []}
        diagram['ownedViews'].append(relation_view)
    diagram['ownedViews'].extend(views.values())
    model['ownedElements'].append(diagram)


def main():
    n1, n2, n3, n2_relations, n3_relations = schemas()
    project = {'_type': 'Project', '_id': uid(), 'name': 'SGCD - normalizacion y modelo objetivo', 'ownedElements': []}
    build_stage(project, '01 Primera forma normal',
                'Valores atomicos y sin grupos repetidos. Todavia existen datos repetidos en las mismas tablas.', n1, [])
    build_stage(project, '02 Segunda forma normal',
                'Se separan dependencias parciales y se agregan tablas puente para claves compuestas.', n2, n2_relations)
    build_stage(project, '03 Tercera forma normal',
                'Se eliminan dependencias transitivas. Este es el modelo final de 14 tablas.', n3, n3_relations)
    build_stage(project, '04 Modelo objetivo completo',
                'Modelo final para adaptar el backend de Nico y el frontend de Eric.', n3, n3_relations)
    OUTPUT.write_text(json.dumps(project, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('UML normalizado escrito:', OUTPUT)


if __name__ == '__main__':
    main()
