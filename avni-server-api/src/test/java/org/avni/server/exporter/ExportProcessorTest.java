package org.avni.server.exporter;

import org.avni.server.dao.EncounterTypeRepository;
import org.avni.server.domain.*;
import org.joda.time.DateTime;
import org.junit.Before;
import org.junit.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Date;
import java.util.HashSet;
import java.util.Set;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

public class ExportProcessorTest {
    @Mock private EncounterTypeRepository encounterTypeRepository;
    @Mock private EncounterType encounterType;
    
    private ExportProcessor processor;
    
    @Before
    public void setUp() {
        MockitoAnnotations.initMocks(this);
        processor = new ExportProcessor(encounterTypeRepository);
    }
    
    @Test
    public void testProcessRegistration() {
        ReflectionTestUtils.setField(processor, "reportType", "Registration");
        
        Individual individual = new Individual();
        individual.setUuid("ind1");
        
        ExportItemRow result = processor.process(individual);
        
        assertNotNull(result);
        assertEquals(individual, result.getIndividual());
        assertNull(result.getProgramEnrolment());
    }
    
    @Test
    public void testProcessEnrolment() {
        ReflectionTestUtils.setField(processor, "reportType", "Enrolment");
        
        Individual individual = new Individual();
        ProgramEnrolment enrolment = new ProgramEnrolment();
        enrolment.setIndividual(individual);
        
        ExportItemRow result = processor.process(enrolment);
        
        assertNotNull(result);
        assertEquals(individual, result.getIndividual());
        assertEquals(enrolment, result.getProgramEnrolment());
    }
    
    @Test
    public void testProcessEncounterWithoutProgram() {
        ReflectionTestUtils.setField(processor, "reportType", "Encounter");
        ReflectionTestUtils.setField(processor, "programUUID", null);
        ReflectionTestUtils.setField(processor, "startDate", new Date());
        ReflectionTestUtils.setField(processor, "endDate", new Date());
        ReflectionTestUtils.setField(processor, "encounterType", encounterType);
        
        when(encounterType.getId()).thenReturn(1L);
        
        Individual individual = new Individual();
        individual.setEncounters(new HashSet<>());
        
        ExportItemRow result = processor.process(individual);
        
        assertNotNull(result);
        assertEquals(individual, result.getIndividual());
    }
    
    @Test
    public void testProcessEncounterWithProgram() {
        ReflectionTestUtils.setField(processor, "reportType", "Encounter");
        ReflectionTestUtils.setField(processor, "programUUID", "prog1");
        ReflectionTestUtils.setField(processor, "startDate", new Date());
        ReflectionTestUtils.setField(processor, "endDate", new Date());
        ReflectionTestUtils.setField(processor, "encounterType", encounterType);
        
        when(encounterType.getId()).thenReturn(1L);
        
        Individual individual = new Individual();
        ProgramEnrolment enrolment = new ProgramEnrolment();
        enrolment.setIndividual(individual);
        enrolment.setProgramEncounters(new HashSet<>());
        
        ExportItemRow result = processor.process(enrolment);
        
        assertNotNull(result);
        assertEquals(individual, result.getIndividual());
        assertEquals(enrolment, result.getProgramEnrolment());
    }
    
    @Test
    public void testProcessGroupSubject() {
        ReflectionTestUtils.setField(processor, "reportType", "GroupSubject");
        
        GroupSubject groupSubject = new GroupSubject();
        
        ExportItemRow result = processor.process(groupSubject);
        
        assertNotNull(result);
        assertEquals(groupSubject, result.getGroupSubject());
    }
}
