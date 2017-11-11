import 'parsing.dart';

String vElement(Iterable<Setter> setters, Iterable<VEvent> events) => '''
  abstract class VElement<E extends Element> extends VNode {
    final vNodeType = VNodeTypes.Element;

    E elementFactory();
    
    bool shouldUpdateSubs = false;

    StyleBuilder styleBuilder;

    List<VNode> _children = new List<VNode>();
    List<VNode> get children => _children;
    void set children(Iterable<VNode> c) {
      _children = c.toList();
    }

    ${attributeDeclarationTemplate(new Setter('text', 'String', ''))}

    ${attributesDeclarationTemplate(setters)}

    ${eventsDeclarationTemplate(events)}

    @protected
    void applyAttributesToElement(E ele) {
      if (_textSet) {
        ${vElementTextUpdate()}
      }
      ${vElementStyleBuilder()}
      ${attributesSetTemplate(setters)}
    }

    @protected
    void updateElementAttributes(covariant VElement<E> prev, E ele) {
      if (_text != prev._text) {
        ${vElementTextUpdate()}
      }
      ${vElementStyleBuilder()}
      ${attributesUpdateTemplate(setters)}
    }

    void applyEventListenersToElement(Element ele) {
      ${eventsSetTemplate(events)}
    }

    void updateEventListenersToElement(VElement prev, Element ele) {
      ${eventsUpdateTemplate(events)}
    }

    void dispose() {
      ${disposeBody(events)}
    }
  }
  ''';

// Workaround: perf is better with this than setting
// the text property directly on the element
String vElementTextUpdate() => '''
  final first = ele.firstChild;
  if (first != null && first == ele.lastChild && first.nodeType == Node.TEXT_NODE) {
    first.text = text;
  } else {
    ele.text = text;
  }
''';

// Workaround: style is final on the element, so VElements can provide
// a fuction to build the style
String vElementStyleBuilder() =>
    'if (styleBuilder != null) styleBuilder(ele.style);';

// Workaround: elements that have multple factories can use this
// to create a custom velements for extra constructors
String customFactoryElement(
        String constructorName, String classElementName, String lib) =>
    '''
  class V$constructorName extends VElement<$classElementName> {
    @override
    $classElementName elementFactory() => new $classElementName.$constructorName();
  }''';

String vElementSubclass(
  String classElementName,
  String superclass,
  Iterable<Setter> setters,
  String lib,
) =>
    '''
  class V$classElementName extends V$superclass<$classElementName> {
    @override
    $classElementName elementFactory() => new $classElementName();

    ${attributesDeclarationTemplate(setters)}

    @override
    @protected
    void applyAttributesToElement($classElementName ele) {
      super.applyAttributesToElement(ele);
      ${attributesSetTemplate(setters)}
    }

    @override
    @protected
    void updateElementAttributes(V$classElementName prev, $classElementName ele) {
      super.updateElementAttributes(prev, ele);
      ${attributesUpdateTemplate(setters)}
    }
  }
''';

String vElementAbstractSubclass(
  String classElementName,
  String superclass,
  Iterable<Setter> setters,
  String lib,
) =>
    '''
  abstract class V$classElementName<T extends $classElementName> extends  V$superclass<T> {
    ${attributesDeclarationTemplate(setters)}

    @override
    @protected
    void applyAttributesToElement(T ele) {
      super.applyAttributesToElement(ele);
      ${attributesSetTemplate(setters)}
    }

    @override
    @protected
    void updateElementAttributes(covariant V$classElementName<T> prev, T ele) {
      super.updateElementAttributes(prev, ele);
      ${attributesUpdateTemplate(setters)}
    }
  }
''';

String attributesDeclarationTemplate(Iterable<Setter> setters) => setters.fold(
    '', (code, setter) => '$code\n${attributeDeclarationTemplate(setter)}');

String attributesSetTemplate(Iterable<Setter> setters) => setters.fold(
    '', (code, setter) => '$code\n${attributeSetTemplate(setter)}');

String attributesUpdateTemplate(Iterable<Setter> setters) => setters.fold(
    '', (code, setter) => '$code\n${attributeUpdateTemplate(setter)}');

String attributeDeclarationTemplate(Setter setter) => '''
  ${setter.type} _${setter.name};
  bool _${setter.name}Set = false;
  ${setter.type} get ${setter.name} => _${setter.name};
  void set ${setter.name}(${setter.type} v) {
      _${setter.name} = v;
      _${setter.name}Set = true;
  }''';

String attributeSetTemplate(Setter setter) =>
    'if (_${setter.name}Set) ele.${setter.name} = _${setter.name};';

String attributeUpdateTemplate(Setter setter) =>
    'if (_${setter.name} != prev._${setter.name}) ele.${setter.name} = _${setter.name};';

String eventsDeclarationTemplate(Iterable<VEvent> events) => events.fold(
    '', (code, event) => '$code\n${eventDeclarationTemplate(event)}');

String eventsSetTemplate(Iterable<VEvent> events) =>
    events.fold('', (code, event) => '$code\n${eventSetTemplate(event)}');

String eventsUpdateTemplate(Iterable<VEvent> events) =>
    events.fold('', (code, event) => '$code\n${eventUpdateTemplate(event)}');

String eventDeclarationTemplate(VEvent event) => '''
    StreamSubscription _${event.name}Sub;
    bool _${event.name}Set = false;
    ${event.type} _${event.name};
    ${event.type} get ${event.name} => _${event.name};
    void set ${event.name}(${event.type} v) {
        _${event.name} = v;
        _${event.name}Set = true;
        shouldUpdateSubs = true;
    }''';

String eventSetTemplate(VEvent event) =>
    'if (_${event.name}Set) _${event.name}Sub = ele.${event.name}.listen(${event.name});';

String eventUpdateTemplate(VEvent event) => '''
    if (_${event.name}Set) {
      if (!prev._${event.name}Set) {
        _${event.name}Sub = ele.${event.name}.listen(${event.name});
      } else if (prev.${event.name} != ${event.name}) {
        prev._${event.name}Sub.cancel();
        _${event.name}Sub = ele.${event.name}.listen(${event.name});
      } else {
        _${event.name}Sub = prev._${event.name}Sub;
      }
    } else if (prev._${event.name}Set) {
      prev._${event.name}Sub.cancel();
    }''';

String disposeBody(Iterable<VEvent> events) =>
    events.fold('', (code, event) => '$code\n_${event.name}Sub?.cancel();');
