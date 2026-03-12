package org.avni.server.exporter;

import org.avni.server.domain.*;
import org.junit.Test;

import java.util.stream.Stream;

import static org.junit.Assert.*;

public class ExportItemRowTest {
    @Test
    public void testSetAndGetIndividual() {
        ExportItemRow row = new ExportItemRow();
        Individual individual = new Individual();
        
        row.setIndividual(individual);
        
        assertEquals(individual, row.getIndividual());
    }
    
    @Test
    public void testSetAndGetProgramEnrolment() {
        ExportItemRow row = new ExportItemRow();
        ProgramEnrolment enrolment = new ProgramEnrolment();
        
        row.setProgramEnrolment(enrolment);
        
        assertEquals(enrolment, row.getProgramEnrolment());
    }
    
    @Test
    public void testSetAndGetGroupSubject() {
        ExportItemRow row = new ExportItemRow();
        GroupSubject groupSubject = new GroupSubject();
        
        row.setGroupSubject(groupSubject);
        
        assertEquals(groupSubject, row.getGroupSubject());
    }
    
    @Test
    public void testSetAndGetEncounters() {
        ExportItemRow row = new ExportItemRow();
        Stream<Encounter> encounters = Stream.empty();
        
        row.setEncounters(encounters);
        
        assertNotNull(row.getEncounters());
    }
    
    @Test
    public void testSetAndGetProgramEncounters() {
        ExportItemRow row = new ExportItemRow();
        Stream<ProgramEncounter> programEncounters = Stream.empty();
        
        row.setProgramEncounters(programEncounters);
        
        assertNotNull(row.getProgramEncounters());
    }
}
